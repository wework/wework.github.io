---
layout:       post
title:        React Reflux to Redux Tutorial
author:       Matt Star
summary:
image:        http://res.cloudinary.com/wework/image/upload/s--xpIlilub--/c_scale,q_jpegmini:1,w_1000/v1443207604/engineering/shutterstock_294201896.jpg
categories:   process
---

There are many great tutorials and boilerplate apps online--linked to in the footer of this post--and even documentation for redux and react itself is fantastic, so for the purposes of this tutorial I'd like to focus on purely how we switched from using reflux to redux in production. You don't necesarilly need a background in Reflux or Redux to understand what's going on, but at least a working knowledge of React is recommended--bonus points for [flux](https://facebook.github.io/flux/docs/overview.html) knowledge as well.

Over the last week or so we took the time to convert our ES5 React Reflux implementation of our [location's flow](https://www.wework.com/locations/new-york-city) into a brand spanking new ES6/7 React ***Redux*** implemenation. We'll go over 3 important examples in our data flow: saving the state of the ui in a store, fetching data from an external API to hydrate our store, and filtering data that is already in our store. This might be redundant, but you'll also get some transitioning from ES5 to ES6/ES7 bonus tips.

## EXAMPLE 1: Store the State of your UI in your...Store

One of the best parts or React, or any componentized framework for that matter is that it's a *declarative* framework--"telling the  'machine' what you would like to happen, and let the computer figure out how to do it"--vs an *imperative* framework--"telling the machine how to do something, and as a result what you want to happen will happen" ([source](http://latentflip.com/imperative-vs-declarative/)).

Let's think about something as simple as hiding or showing extra filters in a list application.

Going from a state where most of the location filters are hidden, with a link that says "More Filters"...

![Filters Hidden](http://res.cloudinary.com/wework/image/upload/s--HveRZzam--/fl_progressive,q_jpegmini:1/v1443360347/engineering/more_filters.jpg)

...to a state where all filters are visible and a link that says "Fewer Filters".

![Filters Expanded](http://res.cloudinary.com/wework/image/upload/s--sM1ilgkF--/fl_progressive,q_jpegmini:1/v1443360347/engineering/fewer_filters.jpg)

### The old way...jquery:

In an *imperative* example using jquery you could have a listener to that specific link, and when it's clicked have it toggle the hidden filters container:

```js
$(".toggle-filters-link").click(function() {
  $(".hidden-filters").toggle();
});
```

Problem with this is, it's super specific, it's not the most reusable piece of code in the world, and it usually just gets dumped into a compiled application.js file that will be hard to find in a production level codebase.

How can we do better???

Let's now look at the more *declarative* example with our initial Reflux implementation.

### The new kid on the block...Reflux:

What if we had access to a boolean that told us whether we should show or hide the hidden filters container? Our React components would listen to that boolean so it would know what to display (...*declarative*), then our link component would simply dispatch an action that would toggle that boolean when clicked.

Following the [Reflux pattern](https://github.com/reflux/refluxjs), let's declare an action--showFiltersActions--to tell the store that we want to toggle the state of "showFilters", and let's create a single store--showFiltersStore--to hold the record of this state.

```js
// src/actions/show_filters_actions.js
var ShowFiltersActions = {};
ShowFiltersActions.toggle = Reflux.createAction();
module.exports = ShowFiltersActions;



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

// ***NOTE: I removed a lot of code from this component not relevant
// to this tutorial:

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


But this tutorial isn't about why you should use React. What about Reflux???


### That new hotness...Redux:

Redux is great. We took the time to rewrite a major piece of functionality in our application because it's so great, and it's a natural successor to reflux (and other flux libraries).

#### Redux: A Quick Intro

We're going to go over a few examples, but take a look at the [Redux docs](https://rackt.github.io/redux/index.html) for a quick overview into why Redux was even created and how it works:

>The whole state of your app is stored in an object tree inside a single store.
>The only way to change the state tree is to emit an action, an object describing what happened.
>To specify how the actions transform the state tree, you write pure reducers.

This sounds similar to the reflux implementation, but the main differences boil down to:

 * **There is only 1 store.** Reflux allows you to create infinite stores, with components picking and choosing the ones to listen to. The Redux pattern has only 1 store, which enforces a React best practice of having 1 parent container for your app that connects to this store, and passes down only the necessary data to each child component.
 * **Dispatching of Actions.** FROM THE [DOCS](https://rackt.github.io/redux/index.html): "Redux doesn’t have a Dispatcher or support many stores. Instead, there is just a single store with a single root reducing function. As your app grows, instead of adding stores, you split the root reducer into smaller reducers independently operating on the different parts of the state tree. This is exactly like there is just one root component in a React app, but it is composed out of many small components." ...a pattern that works very well in a production app

Let's look at the Redux implementation of our showFiltersLink.

A few caveats before diving into the new code:

 * We adopted the [ducks/modules](https://github.com/erikras/ducks-modular-redux) pattern from the [The React/Redux/HotReloader Boilerplate app](https://github.com/erikras/react-redux-universal-hot-example) when building our Redux actions and reducers. This is why our implementation might look slightly different from those in the Redux docs.
 * As we went through the process of converting Reflux to Redux we also upgraded to the new ES6 syntax.

#### Redux: Building a module

First the actionType, action, and reducer in our showFilters module:

```js
// src/redux/modules/show_filters.js

// Define the action type as a constant.
// You'll see how this url style naming convention comes in handy
// later in the redux logger and redux-devtools.

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

import showFilters from './show_filters';
import locations from './locations';

export default combineReducers({
  locations,
  showFilters
});

```

#### Redux: The Setup

The following is about to be a lot of code (taken almost directly from the docs).

We need to initialize our Redux store:

```js
// src/redux/init.js

import { createStore, applyMiddleware } from 'redux';
import thunkMiddleware from 'redux-thunk';
import createLogger from 'redux-logger';

const reducer = require('./modules/reducer');

// Use redux-logger only in dev mode (**REPLACE WITH YOUR ENV**)
const __DEV__ = true;
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

Connect to the Redux API to pass store down to main app component:

```js
// src/containers/root.js

import React, { Component } from 'react';
import App from './app';
import { Provider } from 'react-redux';
import createApiClientStore from '../redux/init';

const store = createApiClientStore();

export default class Root extends Component {
  render() {
    return (
      <Provider store={store}>
        {() => <App /> }
      </Provider>
    );
  }
}
```

And ultimately connect to the store in your parent component to pass down necessary data as props:

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
    // from the connect() function
    const {
      showFilters,
      dispatch
    } = this.props;

    // Bind toggle() action to dispatch() so it hits our Redux root reducing function:
    const actions = bindActionCreators({
      showFiltersToggle
    }, dispatch)

    return (
      <div className="app-wrapper locations-wrapper">
        <section className="location-filters-section">
          // Pass showFilters as well as the toggle() action
          // to be used in the component as props:
          <ShowFiltersLink showFilters={showFilters} actions={actions} />
        </section>
      </div>
    );
  }

}

// Connect to redux store and map the showFilters part of the
// store to props:
export default connect(
  state => ({
    showFilters: state.showFilters
  })
)(App);

```


## EXAMPLE 2: Fetching Data from an External API

Hi

## EXAMPLE 3: Filtering that Fetched Data

Hi

## Tutorials/Docs/Guides

[Dan Abramov's Redux Talk at React Europe](https://www.youtube.com/watch?v=xsSnOQynTHs): Highly recommended watch and it's only 30 minutes. He gets into the reasons why he made redux and shows the incredibly useful [redux-devtools](https://github.com/gaearon/redux-devtools) debugger.

[The React/Redux/HotReloader Boilerplate app](https://github.com/erikras/react-redux-universal-hot-example): Constantly being updated by a vocal and opinionated react community, this was my top resource for patterns (redux modules!) and best practices. I check out this repo daily to see updates and look through the issues. It gets into isomorphic/universal react (server side rendered) and includes many amazing developer tools like the devtools mentioned in Dan Abramov's talk.

[Full-Stack Redux Tutorial](http://teropa.info/blog/2015/09/10/full-stack-redux-tutorial.html): There's a lot in here, but it's nice and comprehensive, and you get step by step instructions.







