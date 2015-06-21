---
layout:       post
title:        Recruiting Through Gamification (Front-End Edition)
author:       Ramin Bozorgzadeh (@i8ramin)
summary:
image:        http://res.cloudinary.com/wework/image/upload/b_rgb:d8edf8,c_pad,f_auto,g_north,h_1000,w_1600/v1430060208/engineering/recruiting-through-gamification.jpg
categories:   hiring
customjs:
  - /bower_components/firebase/firebase-debug.js
  - /bower_components/jsrender/jsrender.min.js
  - /bower_components/typed.js/dist/typed.min.js
  - /js/recruiting-through-gamification.js
customcss:
  - /css/recruiting-through-gamification.css
---

Recruiting top talent is a very challenging task. Every seasoned engineer, manager, recruiter who's had to do it knows this. Give a potential high quality candidate the wrong perception and he/she will quickly move on to another offer. Code challenges are also tricky. They usually target a certain type of engineer and alienate the rest. We think there is a better way and we'd like to run a little experiment to prove it.

As with any experiment, we need volunteers. We will have two self selecting test groups. What do we mean by "self selecting"? Simple, if you choose the **blue pill**, you will be taken to our standard job posting where you can apply like "everyone else". Pick the **red pill** and .. well, you know how that goes. Good luck.

<div class="experiment-buttons">
  <a href="https://www.wework.com/careers?ref=blog#job-49781" target="_blank" class="button button-blue" id="bluePill">Apply Online</a>
  <button class="button button-red" id="redPill" style="display:inline-block;">Oh, Hai. Let's Start</button>
</div>

<div id="game" class="levels">
  <div id="level-0" class="level">
    <div class="title">Level 0</div>
    <panda>
      Hi <b>{name}</b>.^500 My name is <b>Pete</b>.^500 I will be your guide.^500<br>
      You will be presented with a set of challenges.^400<br>
      Complete as many as you can.^400 There are no set time limits, but we are watching...^400
    </panda>
    <button class="button button-small button-blue continue" data-next-level="#level-1">Continue</button>
  </div>

  <div id="level-1" class="level">
    <div class="title">Level 1</div>
    <panda>
      <p>blah blah blah</p>
    </panda>
    <button class="button button-small button-blue continue" data-next-level="#level-2">Continue</button>
  </div>

  <div id="level-2" class="level">
    <div class="title">Level 2</div>
    <panda>
      <p>Wooohooooo</p>
    </panda>
  </div>
</div>

<script id="privatePandaTpl" type="text/x-jsrender">
  <div class="pirate-panda">
    <div class="img"></div>
    <div class="content">
      <div class="chatbox"></div>
    </div>
  </div>
</script>
