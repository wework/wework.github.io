---
layout:       post
title:        Creating BEM Stylesheets for React Components
author:       Rae Farine
summary:
image:        http://res.cloudinary.com/wework/image/upload/s--EfXI0Su2--/c_fill,g_faces,h_1000,q_jpegmini:1,w_1600/v1444612528/bem-stylesheet-react.jpg
categories:   frontend
---

There are plenty of options to choose from when it comes to frontend methodologies.  As I've learned while working with Ember and React.js, web interfaces are composed of powerful components.  When thinking about how to approach the organization of a project, I feel the CSS for each component needs to be just as concise and clear as the Javascript that creates it.

Enter BEM: it stands for "Block", "Element", and "Modifier".  This is no new approach, but it's really begun to grow on me.  I've started to create BEM-style "component" stylesheets here at WeWork, and my main goal is to create "blocks" that are independent of each other, wholey reuseable. Remember, a block may be developed as a singular unit, but it can and **should** be able to appear on a page more than once.

A **block** is *independent* and can be utilized on its own or can contain other blocks (ie. `.location-info {}`.) These can be thought of as parents. The children of blocks are their **elements**, written with two underscores (ie. `.location-info__content {}`.)  **Modifiers** specify the type of block that we're dealing with, so that we can style that component without affecting others (ie. `.location-info--with-background`.)

The markup might look like this:


```html
<div class="location-info location-info--with-background">
    <div class="location-info__content">
        <div class="location-info__image">
            <img src="..." />
        </div>
        <div class="location-info__text">
            <p>Welcome to Soho West!</p>
        </div>
    </div>
</div>
```




A few things to remember:

- HTML Elements must not be used in CSS selectors. We want our classes to be context-free. (ie. In the example above, I should not be applying a style to `.location-info__image img`.)
- ID-based selectors must not be used. We are developing components that are non-unique! There could be multiple blocks/elements on one page.
- Avoid making parent elements when the child can exist by itself.
- You do not need to use BEM for absolutely everything. Just because there is an element in a block, it does not mean it is a BEM element.  Some things just won't fall under the category of BEM. For example, take the class: `.text-center { text-align: center; }`. This is a standalone class, not an element. No need to BEM it up!


## BEM in Action

The BEM methodology has been very useful within our React components. Seeing as we're already creating objects that are wholey reuseable across the site, it only seems natural to make sure that our CSS is as concise.

I was recently creating a new React component for our "Book a Tour" modal, called LocationCmInfo ("Cm" standing for Community Manager, the person giving the tour.)


```js
import React, {Component, PropTypes} from 'react';

class LocationCmInfo extends Component {
  render() {
    const { actions, selectedLocation } = this.props;

    return (
      <div className="modal__content clearfix">
        <div className="location-cm-info">
          <div className="location-cm-info__content">
            <div className="modal__exit" onClick={actions.modalsFlush}>&#215;</div>
            <div className="location-cm-info__image">
              <img src={selectedLocation.community_manager.image_url} />
            </div>
            <div className="location-cm-info__text">
              <h1 className="apercu">Come visit us!</h1>
              <h2 className="apercu">{selectedLocation.name} - {selectedLocation.line1}</h2>
              <p>{selectedLocation.community_manager.name} is a Community Manager at {selectedLocation.name} and will give you a tour of the building.</p>
            </div>
          </div>
        </div>
      </div>
    )
  }
}

LocationCmInfo.propTypes = {
  actions: PropTypes.object.isRequired,
  selectedLocation: PropTypes.object.isRequired
};

export default LocationCmInfo;
```

The markup is incredibly readable and easy to comprehend. We have a block (`.location-cm-info`) that contains an element (`.location-cm-info__content`) containing 2 other elements (`.location-cm-info__image` and `.location-cm-info__text`.) There are no modifiers yet.

I was taking a look at this the other day and realized that **this CSS could use a little refactoring**:

```sass
.location-cm-info {
  &__content {
    position: relative;
    background-color: $syracuse;
    @media #{$medium-up} { padding: 45px; }
    @media #{$small-only} { padding: 30px 25px; }
  }

  &__image {
    border-radius: 50%;
    overflow: hidden;

    @media #{$medium-up} {
      position: absolute;
      top: 45px;
      left: 30px;
    }
    @media #{$small-only} {
      position: relative;
      text-align: center;
      margin: 0 0 15px 0;
    }

    img { width: 100px; height: 100px; }
  }

  &__text {

    @media #{$medium-up} { margin: 0 0 0 120px; }

    @media #{$small-only} { text-align: center; }

    h1, h2 { line-height: 1; }

    h1 {
      font-size: 25px;
      margin: 0 0 12px 0;
    }
    h2 {
      font-size: 15px;
      margin: 0 0 14px 0;
    }
    p { font-size: 11px; margin: 0; }
  }
}
```

I've been breaking my own rule: "Do not use HTML elements in selectors."  Let's first refactor the markup and change the stylesheet accordingly. First of all, I would like to rename this component `.location-info` and add a modifier `--with-cm` to clarify that this module can be used for more than just highlighting a Community Manager.



```html
<div className="location-info--with-cm">
  <div className="location-info__content">
    <div className="location-info__image-container">
      <img className="location-info__image" src={selectedLocation.community_manager.image_url} />
    </div>
    <div className="location-info__text-container">
      <h1 className="location-info__header apercu">Come visit us!</h1>
      <h2 className="location-info__subheader apercu">{selectedLocation.name} - {selectedLocation.line1}</h2>
      <p className="location-info__paragraph">{selectedLocation.community_manager.name} is a Community Manager at {selectedLocation.name} and will give you a tour of the building.</p>
    </div>
  </div>
</div>
```


###What did I change?

- I had to specify that `.locaton-info__image` was in fact a container (`.location-info__image-container`) holding an image with the class `.location-info__image`.
- I also had to specify that the `.location-info__text` was also a container, holding more than one type of text (`h1`, `h2`, `p`) so I renamed it to `.location-info__text-container`
- I added `.location-info__header` to my `h1` tag
- I added `.location-info__subheader` to my `h2` tag
- I added `.location-info__paragraph` to my `p` tag


Now my CSS should change to this:

```sass
$module: 'location-info';

.location-info {
  // .location-info__content
  &__content {
    position: relative;
  }

  // .location-info__text-container
  &__text-container {
    @media #{$medium-up} { margin: 0 0 0 120px; }

    @media #{$small-only} { text-align: center; }
  }

  // .location-info__header, .location-info__subheader
  &__header, &__subheader { line-height: 1; }

  // .location-info__header
  &__header {
    font-size: 25px;
    margin: 0 0 12px 0;
  }

  // .location-info__subheader
  &__subheader {
    font-size: 15px;
    margin: 0 0 14px 0;
  }

  // .location-info__paragraph
  &__paragraph {
    font-size: 11px;
  }

  // .location-info--with-cm
  &--with-cm {
    // .location-info--with-cm .location-info__content
    .#{$module}__content {
      background-color: $syracuse;
      @media #{$medium-up} { padding: 45px; }
      @media #{$small-only} { padding: 30px 25px; }
    }

    // .location-info--with-cm .location-info__image-container
    .#{$module}__image-container {
      border-radius: 50%;
      overflow: hidden;

      @media #{$medium-up} {
        position: absolute;
        top: 45px;
        left: 30px;
      }
      @media #{$small-only} {
        position: relative;
        text-align: center;
        margin: 0 0 15px 0;
      }
    }

    // .location-info--with-cm .location-info__image
    .#{$module}__image { 
      width: 100px; 
      height: 100px; 
    }
  }
}
```

###What did I change?

- Brought in the useful aspect of SASS that allows us to define and interpolate variables (by using: `$module: 'location-info'`). (see an example of this implementation in [Support for BEM modules in Sass 3.3](http://mikefowler.me/2013/10/17/support-for-bem-modules-sass-3.3/)) This came in handy when styling elements within my modifier.
- Moved `.location-info__image` into the modifier `.location-info--with-cm`, **assuming** that in the future, we will not be using an image in our location-info components unless we are displaying the CM's information along with it. Who knows, maybe we *will* want to refactor this in the future, to allow for other types of images to be displayed in our location-info components. But that would just be a simple addition of `.location-info .location-info_image-container` with its own properties. And best of all, that **won't affect** the styles for location-info components with the class `.location-info--with-cm`.
- Moved specific styles for `.location-info__content` to nest under `.location-info--with-cm`, as I doubt that these styles will be used for full-width page view of a LocationInfo component without a CM image. (ie. We probably won't want a gray (`$syracuse`) background when we use LocationInfo without the CM image.)
- Added `.location-info__text-container`, `.location-info__header`, `.location-info__subheader`, and `.location-info__paragraph`.



Immediately, my CSS is more readable, not relying on HTML elements, and context-free. My teammates and I can now create a LocationInfo component using React, and style it without the CM image.  The markup for that might look like this:

```html
<div className="location-info">
  <div className="location-info__content">
    <div className="location-info__text-container">
      <h1 className="location-info__header apercu">Come visit us!</h1>
      <h2 className="location-info__subheader apercu">{selectedLocation.name} - {selectedLocation.line1}</h2>
      <p className="location-info__paragraph">{selectedLocation.name} is a great place to work. We have amenities such as {selectedLocation.amenities}.</p>
    </div>
  </div>
</div>
```

Why should we use BEM? Is it just some pretty syntax sugar to help us make more readable markup? No, it's actually quite helpful in other ways.  Say my product manager comes to me and asks for a new style change on our Location Info component. I can easily check my `_location-info.scss` file and quickly read over which modifiers and elements exist. I might even find that there's already an existing modifier that gets the job done.

>While 100% predictable code may never be possible, it's important to understand the trade-offs you make with the conventions you choose. If you follow strict BEM conventions, you will be able to update and add to your CSS in the future with the full confidence that your changes will not have side effects.

- from "Side Effects in CSS" by [Philip Walton](http://philipwalton.com/articles/side-effects-in-css/)

BEM is also helpful for developers reading the markup who should be able to quickly get an idea of which elements rely on others (ie. `.location-info__image` relies on `.location-info`.)  Even in a short time period of porting our classes over to BEM styles, I've also found that my team members refer to components by their names. This helps when discussing new features and what needs to be created.  Ideally, this naming convention will help both the designers and developers communicate more clearly about changes that need to be made and improve the clarity when discussing UI in general.


**Helpful Links**

- [A New Front-End Methodology: BEM (2012)](http://www.smashingmagazine.com/2012/04/a-new-front-end-methodology-bem/)
- [MindBEMding – getting your head ’round BEM syntax (2013)](http://csswizardry.com/2013/01/mindbemding-getting-your-head-round-bem-syntax/)
- [Support for BEM modules in Sass 3.3 (2013)](http://mikefowler.me/2013/10/17/support-for-bem-modules-sass-3.3/)
- [Side Effects in CSS (2015)](http://philipwalton.com/articles/side-effects-in-css/)



