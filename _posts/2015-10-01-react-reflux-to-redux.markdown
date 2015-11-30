---
layout:       post
title:        React Tutorial - Converting Reflux to Redux
author:       Matt Star
summary:      We converted our React Reflux code to React Redux, and switched over to using ES6 in the process. We'll go over how to save the state of the ui in a store, fetch data from an external API to hydrate our store, and filter data that is already in our store.
image:        http://res.cloudinary.com/wework/image/upload/s--xpIlilub--/c_scale,q_jpegmini:1,w_1000/v1443207604/engineering/shutterstock_294201896.jpg
categories:   process
---

There are many great tutorials and boilerplate apps online--linked to in the footer of this post--and even documentation for redux and react itself is fantastic, so for the purposes of this tutorial I'd like to focus on purely how we switched from using reflux to redux in production. You don't necesarilly need a background in Reflux or Redux specifically to understand what's going on, but at least a working knowledge of React and [Flux](https://facebook.github.io/flux/docs/overview.html) is recommended.

Over the last week or so we took the time to convert our ES5 React Reflux implementation of our [location's flow](https://www.wework.com/locations/new-york-city) into a brand spanking new ES6/7 React ***Redux*** implemenation. We'll go over 3 important examples in our data flow: saving the state of the ui in a store, fetching data from an external API to hydrate our store, and filtering data that is already in our store. This might be redundant, but you'll also get some transitioning from ES5 to ES6/ES7 examples built in.

## EXAMPLE 1: Store the State of your UI in your...Store

Let's think about something as simple as hiding or showing extra filters in a list application.

Going from a state where most of the location filters are hidden, with a link that says "More Filters"...

![Filters Hidden](http://res.cloudinary.com/wework/image/upload/s--HveRZzam--/fl_progressive,q_jpegmini:1/v1443360347/engineering/more_filters.jpg)

...to a state where all filters are visible and a link that says "Fewer Filters".

![Filters Expanded](http://res.cloudinary.com/wework/image/upload/s--sM1ilgkF--/fl_progressive,q_jpegmini:1/v1443360347/engineering/fewer_filters.jpg)

### jquery - the old standby:

Using jQuery you could have a listener to that specific link, and when it's clicked have it toggle the hidden filters container:

```js
$(".toggle-filters-link").click(function() {
  $(".hidden-filters").toggle();
});
```

Problem with this is, it's super specific, it's not the most reusable piece of code in the world, and it usually just gets dumped into a compiled application.js file that will be hard to find in a production level codebase.

### Reflux - the first attempt:

What if we had access to a boolean that told us whether we should show or hide the hidden filters container? Our React components would listen to that boolean so it would know what to display, then our link component would simply dispatch an action that would toggle that boolean when clicked.

Quick flux refresher from their [docs](https://facebook.github.io/flux/docs/overview.html):

![Flux Chart](https://facebook.github.io/flux/img/flux-simple-f8-diagram-explained-1300w.png)

Following the [Reflux pattern](https://github.com/reflux/refluxjs), let's declare an action--showFiltersActions--to tell the store that we want to toggle the state of "showFilters", and let's create a single store--showFiltersStore--to hold the record of this state.

```js

////////// ACTION: //////////
// src/actions/show_filters_actions.js
var ShowFiltersActions = {};
ShowFiltersActions.toggle = Reflux.createAction();
module.exports = ShowFiltersActions;



////////// STORE: //////////
// src/stores/show_filters_store.js
var ShowFiltersActions = require('../actions/show_filters_actions');

var ShowFiltersStore = Reflux.createStore({
  // Connect to the showFiltersActions defined above:
  listenables: ShowFiltersActions,

  init: function() {
    this.showFilters = false;
  },

  // Let's give it a default state of false so the extra filters
  // are hidden by default
  getInitialState: function() {
    return false;
  },

  // Reflux automatically creates action callbacks for each action
  // defined. Format "on#{actionName}":
  onToggle: function () {
    this.showFilters = !this.showFilters

    // In reflux you have to call trigger() to alert the components
    // (and other stores) listening to this store that this store
    // has been updated:
    this.trigger(this.showFilters);
  },
});

module.exports = ShowFiltersStore;

```

Now that we've defined our action and store, let's use them in our components:

```js
// src/components/show_filters_link.js
var ShowFiltersStore = require('../stores/show_filters_store');

var ShowFiltersLink = React.createClass({
  // Connect to the store:
  mixins: [
    Reflux.connect(ShowFiltersStore, 'showFilters')
  ],

  // Call the toggle action onClick:
  toggleFilters: function() {
    ShowFiltersActions.toggle();
  },

  render: function() {
    // The value of the store determines the link text:
    var linkText = this.state.showFilters ? 'Fewer Filters' : 'More Filters'

    return (
      <a
        onClick={this.toggleFilters}
        className="toggle-filters-link" >
          {linkText}
      </a>
    )
  },

});

module.exports = ShowFiltersLink;



// src/components/location_filters.js

var ShowFiltersStore = require('../stores/show_filters_store');
var ShowFiltersLink = require('./show_filters_link')

var LocationFilters = React.createClass({
  // Connect to the store:
  mixins: [
    Reflux.connect(ShowFiltersStore, 'showFilters'),
  ],

  render: function() {

    return (
      <div className='filter-labels-wrapper'>
        <div className='visible-filters'>

          // VISIBLE FILTERS CONTAINER

          <ShowFiltersLink />
        </div>

        // The value of the store determines which class name to use
        // to hide or show the hidden filters container
        <div className={this.state.showFilters ? 'hidden-filters visible' : 'hidden-filters'}>

          // HIDDEN FILTERS CONTAINER

        </div>
      </div>
    )
  },
});

module.exports = LocationFilters;

```

I know this might seem like overkill essentially replacing 3 lines of jquery and a few lines of html with 4 different files between the actions, stores, and components, but this method actually leads to cleaner more reusable--and in my opinion more readable--code, as you start to extend the functionality of your application. What if you wanted to carry the state of your UI through multiple pages on your application? How do you handle reloads? React allows you to handle this complexity in a structured *declarative* manner.


But this tutorial isn't about why you should use Reflux...


### Redux:

When you start building larger production level applications that require many types of stores and a more complex data model, reflux can start to feel a little bloated (TERRIBLE PUN). Redux is a natural successor to reflux (and other flux patterns in general).

#### Redux: A Quick Intro

We're going to go over a few examples, but take a look at the [Redux docs](https://rackt.github.io/redux/index.html) for a quick overview into why Redux was even created and how it works:

>The whole state of your app is stored in an object tree inside a single store.
>The only way to change the state tree is to emit an action, an object describing what happened.
>To specify how the actions transform the state tree, you write pure reducers.

This sounds similar to the reflux implementation, but the main differences boil down to:

 * **There is only 1 store.** Reflux allows you to create infinite stores, with components picking and choosing the ones to listen to. The Redux pattern has only 1 store, which enforces a React best practice of having 1 parent container component for your app that connects to this store, and passes down only the necessary data to each child component as props.
 * **Dispatching of Actions.** FROM THE [DOCS](https://rackt.github.io/redux/index.html): "Redux doesn’t have a Dispatcher or support many stores. Instead, there is just a single store with a single root reducing function. As your app grows, instead of adding stores, you split the root reducer into smaller reducers independently operating on the different parts of the state tree. This is exactly like there is just one root component in a React app, but it is composed out of many small components." ...a pattern that works very well in a production app.

Let's look at the Redux implementation of our showFiltersLink.

A few caveats before diving into the new code:

 * We adopted the [ducks/modules](https://github.com/erikras/ducks-modular-redux) pattern from the [The React/Redux/HotReloader Boilerplate app](https://github.com/erikras/react-redux-universal-hot-example) when building our Redux actions and reducers. This is why our implementation might look slightly different from those in the Redux docs.
 * As we went through the process of converting Reflux to Redux we also updated our code to ES6.

#### Redux: Building a module

The single store concept can seem a little strange coming from the reflux world. In an example where you're filtering locations, it could look something like this:

```js
{
  showFilters: true,
  locations: [
    { name: "Bryant Park" },
    { name: "42nd St"},
    etc...
  ]
}
```

With that in mind, lets first build the actionType, action, and reducer in our showFilters module, which will represent the "showFilters" part of the store object written above:

```js
// src/redux/modules/show_filters.js

// Define the action type as a constant.
// You'll see how this url style naming convention comes in handy
// later when we look at the redux logger and redux-devtools.

const TOGGLE = 'wework.com/showFilters/TOGGLE';


// The reducer that handles an initial state (default false),
// and then returns the updated state when the appropriate
// action (action type TOGGLE) is called:

export default function reducer(state = false, action = {}) {
  switch (action.type) {
    case TOGGLE:
      return !state;
    default:
      return state;
  }
}


// The action that dispatches TOGGLE to the reducer:

export function toggle() {
  return {
    type: TOGGLE
  };
}

```

Next we need to build the single global reducing function. Remember according to the docs, "there is just a single store with a single root reducing function." You'll notice that we're also including the locations reducer that we'll build in EXAMPLE 2 below:

```js
// src/redux/modules/reducer.js

import { combineReducers } from 'redux';

// Import the individual reducers from their respective modules:
import showFilters from './show_filters';
import locations from './locations';

// Using the ES6 object literal shorthand assignment combine them
// to create the store:
export default combineReducers({
  showFilters,
  locations
});

// REMEMBER OUR STORE WILL EVENTUALLY LOOK LIKE THE FOLLOWING

// {
//   showFilters: true,
//   locations: [
//     { name: "Bryant Park" },
//     { name: "42nd St"},
//     etc...
//   ]
// }

```

#### Redux: The Setup

Now that we've set up our single store, how do we get it into the application? Unfortunatley, it looks like [mixins are dead](https://medium.com/@dan_abramov/mixins-are-dead-long-live-higher-order-components-94a0d2f9e750) so we can't use the same pattern we were using in the ES5 Reflux example.

Let's start by initializing our Redux store:

```js
// src/redux/init.js

import { createStore, applyMiddleware } from 'redux';
import thunkMiddleware from 'redux-thunk';
import createLogger from 'redux-logger';

const reducer = require('./modules/reducer');

// Use redux-logger only in dev mode
const __DEV__ = // SOME TYPE OF ENV VARIABLE;
const logger = createLogger({
  predicate: (getState, action) => __DEV__
});

const createStoreWithMiddleware = applyMiddleware(
  thunkMiddleware,
  logger
)(createStore);

export default function createApiClientStore(initialState) {
  return createStoreWithMiddleware(reducer, initialState);
}
```

What you're looking at above is another huge benefit to Reflux: [**Middleware**](https://rackt.github.io/redux/docs/advanced/Middleware.html). You can write custom code to inject extensions into your redux flow, or include already written middleware like [redux-thunk](https://github.com/gaearon/redux-thunk) or [redux-logger](https://github.com/fcomb/redux-logger). We'll need redux-thunk for our external API implementation in Example 2.

Next, let's connect the store to our main `<App />` component using the `<Provider />` component. It "makes our store instance available to the components below." ([DOCS](https://rackt.github.io/redux/docs/basics/UsageWithReact.html))

```js
// src/containers/root.js

import React, { Component } from 'react';
import App from './app';
import { Provider } from 'react-redux';
import createApiClientStore from '../redux/init';


// Import the store created in init.js
const store = createApiClientStore();

export default class Root extends Component {
  render() {
    return (
      // Connect the App component to this new redux API Client Store
      <Provider store={store}>
        {() => <App /> }
      </Provider>
    );
  }
}
```

And ultimately connect the `<App />` component to the store to pass down necessary data as props to it's child components:

```js
// src/containers/app.js

// Import dependencies:
import React, { Component, PropTypes } from 'react';
import { bindActionCreators } from 'redux';
import { connect } from 'react-redux';

// Import toggle() action from show_filters redux module:
import {toggle as showFiltersToggle} from '../redux/modules/show_filters';

// Import Link component:
import ShowFiltersLink from '../components/show_filters_link';

class App extends Component {
  render() {
    // Notice dispatch() from the Redux API is included as a prop
    // from the connect() function.
    const {
      showFilters,
      dispatch
    } = this.props;

    // Bind toggle() action to dispatch(). You need to bind all
    // actions to dispatch() or it will not be picked up by the
    // combined Reducer created in src/redux/modules/reducer.js
    const actions = bindActionCreators({
      showFiltersToggle
    }, dispatch)

    return (
      <div className="app-wrapper locations-wrapper">
        <section className="location-filters-section">
          // Pass down showFilters as well as the toggle() action as props:
          <ShowFiltersLink showFilters={showFilters} actions={actions} />
        </section>
      </div>
    );
  }

}

// Connect to redux store and map the showFilters part of the
// store to props (this also maps dispatch() as a prop):
export default connect(
  state => ({
    showFilters: state.showFilters
  })
)(App);

```

Now, all you have to do is use your props like you normally would in your components:

```js
// src/components/show_filters_link.js

import React, {Component, PropTypes} from 'react';

class ShowFiltersLink extends Component {
  render() {
    const {actions, showFilters} = this.props;

    const linkText = showFilters ? 'Fewer Filters' : 'More Filters'

    return (
      <a
        onClick={actions.showFiltersToggle}
        className="toggle-filters-link" >
          {linkText}
      </a>
    )
  }
}

ShowFiltersLink.propTypes = {
  actions: PropTypes.object,
  showFilters: PropTypes.bool
};

export default ShowFiltersLink;

```

## EXAMPLE 2: Fetching Data from an External API

Now that we have the basics of redux under our belt, let's look at hydrating the store with data from an external API.

```js
// Dependency for our external API call:
import fetch from 'isomorphic-fetch';

// Create our Action Types:
const LOAD = 'wework.com/locations/LOAD';
const LOAD_SUCCESS = 'wework.com/locations/LOAD_SUCCESS';


// Build our Reducer with a default state of an empty array:
const initialState = {
  loaded: false,
  data: []
};

export default function reducer(state = initialState, action) {
  switch (action.type) {
  case LOAD:
    return {
      ...state,
      loading: true
    };
  case LOAD_SUCCESS:
    return {
      ...state,
      loading: false,
      loaded: true,
      lastUpdated: Date.now(),
      data: action.data
    };
  default:
    return state;
  }
}

// Build our actions
function requestLocations() {
  return {
    type: LOAD
  };
}

function receiveLocations(json) {
  return {
    type: LOAD_SUCCESS,
    data: json,
    receivedAt: Date.now()
  };
}


// Build action creaters that return a function instead of the
// actions above (thanks to redux-thunk middleware):
function fetchLocations() {
  // thunk middleware knows how to handle functions
  return function (dispatch) {
    dispatch(requestLocations());

    // Return a promise to wait for
    // (this is not required by thunk middleware, but it is convenient for us)
    return fetch(DATA_URL_ENDPOINT_THAT_RETURNS_JSON)
      .then(response => response.json())
      .then(json =>
        // We can dispatch many times!
        dispatch(receiveLocations(json))
      );
  };
}

export function isLoaded(globalState) {
  return globalState.locations && globalState.locations.loaded;
}

// No need to call the external API if data is already in memory:
export function fetchLocationsIfNeeded() {
  return (dispatch, getState) => {
    if ( isLoaded(getState()) ) {
      // Let the calling code know there's nothing to wait for.
      return Promise.resolve();
    } else {
      // Dispatch a thunk from thunk!
      return dispatch(fetchLocations());
    }
  };
}

```

A nice feature to this pattern is we dispatch the `receiveLocations()` action once data is received from the API. That forces a state change which causes our components to re-render, updating the view.

With the new locations module written, and everything already setup in EXAMPLE 1 to handle this new locations reducer, all we have to do is now connect to this part of the store in our main `<App />` component.

```js
// src/containers/app.js

// Import dependencies:
import React, { Component, PropTypes } from 'react';
import { bindActionCreators } from 'redux';
import { connect } from 'react-redux';

// Import actions from locations module for hydrating redux
// store with data from server:
import * as LocationActions from '../redux/modules/locations';

// Import toggle() action from show_filters redux module:
import {toggle as showFiltersToggle} from '../redux/modules/show_filters';

// Import components:
import ShowFiltersLink from '../components/show_filters_link';
import LocationList from '../components/location_list';

class App extends Component {
  // Make sure we call the API endpoint before our component is mounted:
  componentWillMount() {
    const {dispatch} = this.props;

    // Bind redux actions to dispatch():
    const actions = bindActionCreators({ ...LocationActions }, dispatch)

    // Call action:
    actions.fetchLocationsIfNeeded();
  }

  render() {
    // Now also listen for locations as props:
    const {
      locations,
      showFilters,
      dispatch
    } = this.props;

    // Bind redux actions to dispatch()
    const actions = bindActionCreators({
      showFiltersToggle
    }, dispatch)

    return (
      <div className="app-wrapper locations-wrapper">
        <section className="location-filters-section">
          // Pass down showFilters as well as the toggle() action as props:
          <ShowFiltersLink showFilters={showFilters} actions={actions} />
        </section>

        <section className="content-section">
          // Pass down locations as props:
          <LocationList locations={locations} />
        </section>
      </div>
    );
  }

}

// Connect to redux store and map to props
export default connect(
  state => ({
    locations: state.locations,
    showFilters: state.showFilters
  })
)(App);

```

## EXAMPLE 3: Filtering that Fetched Data

What if we want to filter any of our existing data? For that you use [reselect](https://rackt.github.io/redux/docs/recipes/ComputingDerivedData.html). Reselect allows you to create memoized selectors that only update when the sections of the store that it is listening to are updated.

In the example of filtering locations:

```js
// src/redux/selectors/locations_selector.js

import { createSelector } from 'reselect';

// The function that receives the updated locations from the
// locationsSelector and ultimately filters those locations:

function filterLocations(locations) {
  return locations.data.filter(function(location) {
    // FILTER YOUR LOCATIONS!
  });
}


// FROM THE DOCS: Input-selectors should be used to abstract away
// the structure of the store in cases where no calculations are
// needed and memoization wouldn't provide any benefits.

const locationsSelector = state => state.locations;


// FROM THE DOCS: In filteredLocationsSelector, input-selectors are
// combined to derive new information. To prevent expensive recalculation
// of the input-selectors memoization is applied. Hence, these selectors
// are only recomputed when the value of their input-selectors change.
// If none of the input-selectors return a new value, the previously
// computed value is returned.

export const filteredLocationsSelector = createSelector(
  locationsSelector,
  filterLocations
);
```

Now all we have to do is tell the `<App />` component to listen to the filteredLocationsSelector instead of the locations part of the store.

```js
// src/containers/app.js

.......

// Import selectors:
import { filteredLocationsSelector } from '../redux/selectors/locations_selector';

class App extends Component {

.......

}

// Connect to redux store and map to props now using the
// filteredLocationsSelector()
export default connect(
  state => ({
    locations: filteredLocationsSelector(state),
    showFilters: state.showFilters
  })
)(App);

```

## Tutorials/Docs/Guides

[Dan Abramov's Redux Talk at React Europe](https://www.youtube.com/watch?v=xsSnOQynTHs): Highly recommended watch and it's only 30 minutes. He gets into the reasons why he made redux and shows the incredibly useful [redux-devtools](https://github.com/gaearon/redux-devtools) debugger.

[The React/Redux/HotReloader Boilerplate app](https://github.com/erikras/react-redux-universal-hot-example): Constantly being updated by a vocal and opinionated react community, this was my top resource for patterns (redux modules!) and best practices. I check out this repo daily to see updates and look through the issues. It gets into isomorphic/universal react (server side rendered) and includes many amazing developer tools like the devtools mentioned in Dan Abramov's talk.

[Full-Stack Redux Tutorial](http://teropa.info/blog/2015/09/10/full-stack-redux-tutorial.html): There's a lot in here, but it's nice and comprehensive, and you get step by step instructions.







