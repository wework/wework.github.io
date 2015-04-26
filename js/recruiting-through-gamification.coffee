---
# required for coffeescript to work
---

class Panda
  constructor: (containerEl) ->
    @chatSettings =
      startDelay: 300
      backSpeed: 0
      backDelay: 500
      typeSpeed: 0
      showCursor: false
      contentType: 'html'

    containerEl = $(containerEl)
    pandaTpl = $.templates('#privatePandaTpl').render()
    pandaEl = containerEl.find('panda')
    strings = []

    pandaEl.find('p').each (i, p) =>
      strings.push $(p).text()

    @chatSettings.strings = strings

    pandaEl.replaceWith(pandaTpl)

    @element = containerEl.find('.pirate-panda')
    @chatBox = @element.find('.chatbox')
    return
  talk: ->
    console.log(@chatSettings)
    @chatBox.typed(@chatSettings)
    return

class Level
  constructor: (levelEl) ->
    @levelEl = levelEl
    @panda = new Panda(@levelEl)
    @panda.talk()
  greet: (text) ->
    @panda.say(text)

class Game
  constructor: () ->
    @redPill = $('#redPill')
    @levels = []
    return
  init: ->
    $('.levels .level').each (i, level) =>
      @levels.push new Level(level)
    @currentLevel = @levels.splice(0, 1)
    return

$ ->
  window.game = new Game()
  game.init()

  # bluePill = $('#bluePill')
  # redPill = $('#redPill')
  # expCanvas = $('#expCanvas')
  # piratePanda = $('#piratePanda')
  # chatBox = piratePanda.find('.chatbox')
  # continueButton = piratePanda.find('.button.next')

  # chatSettings =
  #   startDelay: 300
  #   backSpeed: 0
  #   backDelay: 500
  #   typeSpeed: 0
  #   showCursor: false
  #   contentType: 'html'

  # redPill.on 'click', (e) ->
  #   e.preventDefault()

  #   $('html, body').css
  #     overflow: 'hidden'

  #   expCanvas.addClass('active')

  #   chatSettings.strings = [
  #     "Well done! You've made it to level 0.^300",
  #     "Don't worry, it'll get more interesting from here...."
  #   ]

  #   chatSettings.resetCallback = () -> chatBox.removeClass('done-typing')
  #   chatSettings.callback = () -> chatBox.addClass('done-typing')

  #   chatBox.typed(chatSettings)

  #   continueButton.on 'click', (e) ->
  #     chatBox.removeClass('done-typing')
  #     expCanvas.find('.inner-wrapper').css
  #       maxWidth: '90%'


  #     chatSettings.strings = [
  #       "Area you ready for level 1?"
  #     ]

  #     chatBox.typed(chatSettings)
