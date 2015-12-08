---
layout:       post
title:        Building Static Sites with React, Redux, Webpack, and Roots
author:       matt_star
summary:      Our main marketing site (wework.com) used to be a slow monolithic Rails app. This is how we converted it to use Roots, React, and Webpack and decreased our page load speed by over 50%.
image:        http://res.cloudinary.com/wework/image/upload/s--xpIlilub--/c_scale,q_jpegmini:1,w_1000/v1443207604/engineering/shutterstock_294201896.jpg
categories:   engineering
---

If you read our [last post](http://engineering.wework.com/engineering/2015/12/08/why-wework-com-uses-a-static-generator-and-why-you-should-too/) you know all about why we decided to use a static site generator for the new wework.com. If you're also familiar with our [reflux to redux tutorial](http://engineering.wework.com/process/2015/10/01/react-reflux-to-redux/), you'll see that we use React and Redux to power the wework.com [Locations Flow](https://www.wework.com/locations/new-york-city/).

## Server Side Rendering

Why is server side rendering so great? Here are two examples of our [New York City](https://www.wework.com/v2/locations/new-york-city/) page.

**Without server side rendering:**

![Location Flow Without Server Rendering](http://res.cloudinary.com/wework/image/upload/s--h0Dj3ybV--/c_scale,fl_progressive,q_jpegmini,w_1000/v1449600122/engineering/Screen_Shot_2015-12-08_at_1.37.19_PM.jpg)

**With server side rendering:**

![](http://res.cloudinary.com/wework/image/upload/s--AxqGjxt---/c_scale,fl_progressive,q_jpegmini,w_1000/v1449600397/engineering/Screen_Shot_2015-12-08_at_1.45.52_PM.jpg)

When we initially built this flow, all of our React logic was being initialized through [ReactDOM.render](https://facebook.github.io/react/docs/top-level-api.html#reactdom.render). The page coming back from the server would be blank (just header and footer) and then when the DOM was ready, react would kick in and load the page accordingly. There are many great [tutorials and examples](https://github.com/DavidWells/isomorphic-react-example#other-isomorphic-tutorials--resources) on how to spin up a quick express server to render your components to string and output them as html. However, once we moved to a static site generator, we no longer had a server.

## Static React Rendering

This isn't quite server side rendering, isomorphic react, universal react, or whatever you want to call it because we don't have a server. However, this still uses the same concepts as server side rendering. We use the same logic, but instead of doing it on an express server, we pass it through a Webpack static site generator plugin to compile the html and save it to our public folder. We took a lot of cues from this excellent [tutorial on creating static pages with React components](http://jxnblk.com/writing/posts/static-site-generation-with-react-and-webpack/). We're still working on a more ideal implementation, but it boils down to the following:

* [Roots](http://roots.cx/) (our static site generator) is responsible for compiling all non-react static pages
* Webpack is responsible for compiling all views that use react
* webpack-dev-server is responsible for serving all pages (both roots and react) in development

When we compile to production, it's now as easy as running `roots compile -e production && npm run build`.

In a perfect world we'd have all the roots logic run through webpack as well. Luckily the team at carrot creative is currently working on the next implementation of Roots that does just that!


## Using React, React Router, and Redux

First, let's assume the following in your webpack.config.js:

```js

var path                         = require("path");
var oui                          = require('@wework/oui');
var ExtractTextPlugin            = require("extract-text-webpack-plugin");
var StaticGeneratorFromUrlPlugin = require('./src/static-generator-plugin.js');

// Format url object for StaticGeneratorFromUrlPlugin plugin:
var formatUrl = function(url, token) {
  return {
    url: {
      path: url,
      headers: { 'Authorization': 'Token token=' + token },
    }
  }
};

var markets_api_url = process.env.DUBS_API + '/api/v1/markets'
var markets_url_object = formatUrl(markets_api_url, process.env.DUBS_API_TOKEN)

var config = {
  entry: {
    'base': './src/base_entry.js',
    'main': './src/main_entry.js',
    'home': './src/home_entry.js',
    'react_base': './src/react_base_entry.js',
    'market_page': './src/market_page_entry.js',
  },

  output: {
    path: path.join(__dirname, "public"),
    filename: "js/[name].bundle.js",
    libraryTarget: 'umd',
  },

  externals: {
    "_": "_",
    "jquery": "jQuery",
    "Modernizr": "Modernizr",
  },

  module: {
    loaders: [
      {
        test: /\.jade$/,
        loader: 'jade-loader',
        exclude: /node_modules/
      },
      {
        test: /\.jsx?$/,
        loader: 'transform?envify!babel',
        include: [
          path.resolve(__dirname, "node_modules/@wework/oui/src"),
          path.resolve(__dirname, "assets/js"),
          path.resolve(__dirname, "src"),
        ],
      },
      {
        test: /\.css$/,
        loader: ExtractTextPlugin.extract('css-loader'),
        include: [
          path.resolve(__dirname, "node_modules/@wework/oui/src"),
          path.resolve(__dirname, "src"),
        ],
      },
      {
        test: /\.styl$/,
        loader: ExtractTextPlugin.extract('css!stylus'),
        include: [
          path.resolve(__dirname, "node_modules/@wework/oui/src"),
          path.resolve(__dirname, "src"),
          path.resolve(__dirname, "assets"),
        ],
      },
      {test: /\.json$/, loader: 'json', exclude: /node_modules/},
    ]
  },

  stylus: {
    'use': [oui({ implicit: false })],
    'include css': true,
  },

  plugins: [
    new StaticGeneratorFromUrlPlugin('js/market_page.bundle.js', markets_url_object),
    new ExtractTextPlugin("/css/[name].styles.css"),
  ]
}

module.exports = config;

```

Let's take a look at our webpack entry file to see what's going on:

```js
import React from 'react';
import ReactDOM from 'react-dom/server';
import { render as renderDOM } from 'react-dom';
import { Router, Route, match, RoutingContext } from 'react-router';
import createBrowserHistory from 'history/lib/createBrowserHistory';
import { Provider } from 'react-redux';

import createApiClientStore from './redux/init';
import MarketPage from './containers/MarketPage/MarketPage';

// TODO: Figure out why we need no / for
// the static site version and the extra /
// for the client side render:
const routes = ([
  <Route path="/v2/locations/:market" component={MarketPage} />,
  <Route path="/v2/locations/:market/" component={MarketPage} />,
]);

// Client Side Render:
if (typeof document !== 'undefined') {
  // Fetch initial state from Server Rendered HTML:
  const initialState = JSON.parse(window.__INITIAL_STATE__.replace(/&quot;/g, '"'));
  const history = createBrowserHistory();
  const store = createApiClientStore(initialState);

  renderDOM(
    <Provider store={store}>
      <Router children={routes} history={history} />
    </Provider>,
    document.getElementById('content')
  );
}

// Use layout.jade from roots as main layout file for react pages:
const defaultLocals = require('../lib/locals.json');
const marketsByCountry = require('../lib/marketsByCountry.json');
const template = require('../views/layout.react.jade');

// Exported static site renderer:
module.exports = function render(locals, callback) {
  const initialState = {
    market: {
      loading: false,
      data: locals.data,
    },
  };

  // React Router 1.0 server side syntax:
  // https://github.com/rackt/react-router/blob/master/docs/guides/advanced/ServerRendering.md
  match({ routes, location: locals.path }, (error, redirectLocation, renderProps) => {
    const store = createApiClientStore(initialState);
    const initialReduxState = JSON.stringify(store.getState());

    const html = ReactDOM.renderToString(
      <Provider store={store}>
        <RoutingContext {...renderProps} />
      </Provider>
    );

    defaultLocals._path = '';
    defaultLocals.appContent = html;
    defaultLocals.description = locals.data.seo_page_title;
    defaultLocals.title = locals.data.seo_page_title;
    defaultLocals.initialState = initialReduxState;
    defaultLocals.records = { marketsByCountry: marketsByCountry };

    callback(null, template(defaultLocals));
  });
};

```











