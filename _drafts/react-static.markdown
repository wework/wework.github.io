---
layout:       post
title:        Building Static Sites with React, Redux, Webpack, and Roots
author:       Matt Star
summary:      Our main marketing site (wework.com) used to be a slow monolithic Rails app. This is how we converted it to use Roots, React, and Webpack and decreased our page load speed by over 50%.
image:        http://res.cloudinary.com/wework/image/upload/s--xpIlilub--/c_scale,q_jpegmini:1,w_1000/v1443207604/engineering/shutterstock_294201896.jpg
categories:   process
---

The WeWork Engineering team is made up of mostly Rails engineers. When we made the decision over a year ago to bring [wework.com](https://www.wework.com) in house it was a no brainer to use Rails--we could get up and running more quickly and have all engineers contribute to the project. However, as we've grown our team, experimented with new technologies ([React and Redux](/process/2015/10/01/react-reflux-to-redux/)), and grown as a company in size and scope, not only has our Rails app balooned into a monolithic headache, but we're starting to see increasing page load times--and as a consequence declining SEO and poor user experience. We needed to move off of Rails.

We had three engineering requirements:

1. These pages need to be FAST.
2. Create one off (potentially dynamic) landing pages as quickly as possible.
3. Use React for our some of our more complicated views.

## Go Static - Roots.cx

For the first two requirements, we turned to the (Roots)[http://roots.cx/] static site generator. I'll let you dig into the docs, but we were able to create static compiled HTML/CSS/JS pages very quickly, and by having them hosted on a CDN (we use [Netlify](http://netlify.com/)) saw a massive page speed increase.

Roots takes all `.jade` files in your `/views` directory, and compiles them down to your `public` directory as raw html ready to be served.

You might be asking, wouldn't you see the same result by CDN caching the Rails app? Well, sorta! And that's what we did initially. However, as your site grows there are many issues that you'll start to run into.

#### The Asset Pipeline

This was our biggest issue by far. One of the biggest advantages of Rails is its ability to magically compile all your css/sass and js/coffeescript when you build your application up to heroku (or wherever you're hosting). However, what if you start building one off landing pages that don't need all the compiled css and js from application.css and application.js?

We started by creating multiple layout files that only include the necessary JS and CSS, but that's not really what Rails was built to support. Now you're adding `layout: :INSERT_LAYOUT_FILE_NAME` into your controller actions and contributing to overall bloat.

Our next solution was experimenting with integrating webpack and React. At that point, you should just be building a node app rather than retrofitting Rails to do somthing it didn't intend to do in the first place.

With Roots and static it was quite simple to only include the necessary Javascript and CSS to keep our pages as slim as possible.

#### Server Side Rendering

What if you want to use React in a Rails project? On our old Rails site we used React to build our [Locations flow](https://www.wework.com/locations/new-york-city/). The page coming back from the server would be blank (just header and footer) and then when the DOM was ready, react would kick in and load the page accordingly. All of our React logic was being compiled in Application.js so it was unfortunately only client side. This was probably the biggest reason we switched off of Rails and embraced static.

## Static React

This isn't quite server side rendering, isomorphic react, universal react, or whatever you want to call it because we don't have a server. However, this still uses the same concepts as server side rendering. Instead of allowing an Express server for example to render and serve the page, we use the same logic and pass it through a Webpack static site generator plugin to compile the html and save it to our public folder. We took a lot of cues from this excellent [tutorial on creating static pages with React components](http://jxnblk.com/writing/posts/static-site-generation-with-react-and-webpack/). We're still working on a more ideal implementation, but it boils down to the following:

* Roots is responsible for compiling all non-react static pages
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











