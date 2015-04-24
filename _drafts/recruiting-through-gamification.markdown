---
layout:       post
title:        Recruiting Through Gamification
author:       Ramin Bozorgzadeh (@i8ramin)
summary:
image:        http://res.cloudinary.com/wework/image/upload/b_rgb:d8edf8,c_pad,f_webp,fl_awebp,fl_progressive,h_1000,w_1600/v1429798998/recruiting-through-gamification.jpg
categories:   hiring
customjs:
  - /bower_components/typed.js/dist/typed.min.js
  - /rabbit-hole/main.js
customcss:
  - /rabbit-hole/styles.css
---

Recruiting top talent is a very challenging task. Every seasoned engineer, manager, recruiter who's had to do it knows this. Give a potential high quality candidate the wrong perception and he/she will quickly move on to another offer. Code challenges are also tricky. They usually target a certain type of engineer and alienate the rest. We think there is a better way and we'd like to run a little experiment to prove it.

As with any experiment, we need volunteers. We will have two self selecting test groups. What do we mean by "self selecting"? Simple, if you choose the **blue pill**, you will be taken to our standard job posting where you can apply like "everyone else". Pick the **red pill** and .. well, you know how that goes. Good luck.

<div class="experiment-buttons">
  <a href="https://www.wework.com/careers?ref=blog#job-49781" target="_blank" class="button button-blue" id="bluePill">Apply Online</a>
  <button class="button button-red" id="redPill" style="display:none;">Oh, Hai. Let's Start</button>
</div>

<div id="expCanvas" class="level-0">
  <div class="innerWrapper">
    <div id="piratePanda">
      <div class="img"></div>
      <div class="chatbox"></div>
    </div>
    <div class="level-0"></div>
  </div>
</div>

<script id="testCanvas" type="text/x-jsrender">
  <div id="rh-Canvas">
  </div>
</script>
