---
# required for coffeescript to work
---

$ ->
  bluePill = $('#bluePill')
  redPill = $('#redPill')
  expCanvas = $('#expCanvas')
  piratePanda = $('#piratePanda')

  redPill.on 'click', (e) ->
    e.preventDefault()
    $('html, body').css
      overflow: 'hidden'

    expCanvas.addClass('active')

    piratePanda.find('.chatbox').typed
      strings: ["First sentence.", "Second sentence."]
