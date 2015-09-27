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
// src/actions/show_filters_actions.js.jsx
var ShowFiltersActions = {};
ShowFiltersActions.toggle = Reflux.createAction();
module.exports = ShowFiltersActions;



// src/stores/show_filters_store.js.jsx
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
// src/components/show_filters_link.js.jsx
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



// src/components/location_filters.js.jsx

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



## EXAMPLE 2: Fetching Data from an External API

Hi

## EXAMPLE 3: Filtering that Fetched Data

Hi






