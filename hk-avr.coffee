# hk AVR plugin
module.exports = (env) ->

  Promise = env.require 'bluebird'
  commons = require('pimatic-plugin-commons')(env)
  api = require('./hk-avr-api')(env)
  deviceConfigTemplates = [
    {
      "name": "Hk AVR Power",
      "class": "hkAvrPowerSwitch"
    }
    {
      "name": "Hk AVR Mute",
      "class": "hkAvrMuteSwitch"
    }
    {
      "name": "Hk AVR Master Volume",
      "class": "hkAvrMasterVolume",
      "maxAbsoluteVolume": 89.5
    }
    {
      "name": "Hk AVR Input Selector",
      "class": "hkAvrInputSelector",
    }
  ]

  actionProviders = [
    'hk-avr-input-select-action'
  ]

  # ###hkAvrPlugin class
  class HkAvrPlugin extends env.plugins.Plugin
    init: (app, @framework, @config) =>
      @debug = @config.debug || false
      @base = commons.base @, 'Plugin'
      @api = new api @config

      # register devices
      deviceConfigDef = require("./device-config-schema")
      for device in deviceConfigTemplates
        className = device.class
        # convert camel-case classname to kebap-case filename
        filename = className.replace(/([a-z])([A-Z])/g, '$1-$2').toLowerCase()
        classType = require('./devices/' + filename)(env)
        @base.debug "Registering device class #{className}"
        @framework.deviceManager.registerDeviceClass(className, {
          configDef: deviceConfigDef[className],
          createCallback: @_callbackHandler(className, classType)
        })

      for provider in actionProviders
        className = provider.replace(/(^[a-z])|(\-[a-z])/g, ($1) ->
          $1.toUpperCase().replace('-','')) + 'Provider'
        classType = require('./actions/' + provider)(env)
        @base.debug "Registering action provider #{className}"
        @framework.ruleManager.addActionProvider(new classType @framework)

      # auto-discovery
      @framework.deviceManager.on('discover', (eventData) =>
        @framework.deviceManager.discoverMessage 'pimatic-hk-avr', 'Searching for AVR controls'
        for device in deviceConfigTemplates
          matched = @framework.deviceManager.devicesConfig.some (element, iterator) =>
            #console.log element.class is device.class, element.class, device.class
            element.class is device.class

          if not matched
            process.nextTick @_discoveryCallbackHandler('pimatic-hk-avr', device.name, device)
      )

    _discoveryCallbackHandler: (pluginName, deviceName, deviceConfig) ->
      return () =>
        @framework.deviceManager.discoveredDevice pluginName, deviceName, deviceConfig

    _callbackHandler: (className, classType) ->
      # this closure is required to keep the className and classType
      # context as part of the iteration
      return (config, lastState) =>
        return new classType(config, @, lastState)

  # ###Finally
  # Create a instance of my plugin
  # and return it to the framework.
  return new HkAvrPlugin