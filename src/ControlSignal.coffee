async = require 'async'

###
# ControlSignal module #

This module *is* the ControlSignal class.
You should really be looking at that instead!
###

class ControlSignal
  ###
  The ControlSignal provides a simple and special signal-slot implementation.
  However, it should not be used to implement the Observer pattern per se
  because it allows the creation of hooks that return values that influence
  the owner's operations.

  The ControlSignal is a fully asynchronous class (where it counts). The emission
  of a signal is an async operation. All of its slots must be async functions.

  The ControlSignal itself does not define how it handles the "return" values of
  the async slots. Instead, during construction, you must provide a processor.
  This function receives an array of all the slots' results and has full
  control of what ultimately makes it to the emission callback.
  Note that all slots calls are performed "in parallel" and then processsed
  synchronously thereafter.

  The ControlSignal provides some class functions that create special instances
  with built-in processors. In fact, the ControlSignal should be treated as a
  low-level class. Use the special class functions whenever possible.
  ###

  constructor: (@paramCount, @processor) ->
    ###
    Constructs a new ControlSignal.

    ##\##\# Arguments
    `@paramCount`  
    The number of parameters the signal will emit, excluding the obligatory callback.
    A ControlSignal cannot be variadic. This number must be 0 or greater.s

    `@processor`  
    This function is called after all the slots have been executed. It is given an array of
    all the slots' results. Whatever the processor function returns is then given to the
    emission callback. Note that this function is executed synchronously. It is given only
    one parameter. If it throws an exception, it will be given to the emission callback as
    the error.

    ##\##\# Exceptions
    Throws RangeError if the `paramCount` is less than 0.
    ###
    throw new RangeError "ControlSignal paramCount must be greater or equal to 0" if @paramCount < 0
    @_slots = []

  connect: (slot) ->
    ###
    Registers a persistent, asynchronous slot.
    If the slot was already registered, it will be registered
    again and, therefore, invoked multiple times for each emission.

    ##\##\# Arguments
    `slot`  
    The slot. Must be a function. The last argument passed
    to this function will always be the asynchronous callback which
    must be called when the listener is done. The callback takes
    two parameters: the error, if any, and the result. The result
    is given to the emission callback after being processed by the
    signal's processor.

    The arity of the slot must match the `paramCount` of
    the signal, taking the obligatory callback into consideration.
    (That is, the arity must equal `paramcount + 1`.)

    ##\##\# Returns
    null

    ##\##\# Exceptions
    Throws Error if arity doesn't match signal's (see the definition of `slot`
    above).

    ###
    if slot.length != @paramCount + 1 # +1 for callback
      throw new Error "slot's arity does not match signal's (#{slot.length-1} != #{@paramCount} excluding callback)"
    @_slots.push slot
    null

  disconnect: (slot) ->
    ###
    Removes a given slot.

    If the slot was registered multiple times, only one
    registration will be removed. The slot will continue
    to be invoked by the other registrations.

    ##\##\# Arguments
    `slot`  
    The slot as provided to `connect`. Must be a function.

    ##\##\# Returns
    True if a slot was removed; false otherwise.
    ###
    for s, i in @_slots by -1
      if s == slot
        @_slots.splice(i, 1)
        return true
    false

  receivers: ->
    ###
    Gets the number of slots registered.
    
    ##\##\# Returns
    The number of slots registered.
    If a slot was registered multiple times, it will be
    included multiple times in the count.
    ###
    @_slots.length

  emit: (args..., callback) ->
    ###
    Emits the signal, calling all slots registered.

    ##\##\# Arguments
    `args...`  
    Arguments to pass to the slots, excluding the callback, which
    is automatically provided for you. The number of arguments must therefore
    be equal to the signal's `paramCount`.

    `callback(error, value)`  
    The async callback. `error` will be the first error encountered
    or `null` if none were. The `value` will be the result of the
    reduce operation against all the slots' results unless there
    is an error, in which case it will be null.

    ##\##\# Returns
    This is an asynchronous function. The results are provided to the
    callback. However, the function itself returns null.

    ##\##\# Exceptions
    Throws Error if the number of arguments does not equal the `paramCount`
    (see the definition of `args...` above).
    ###
    if arguments.length != @paramCount + 1
      throw new Error "incorrect number of arguments provided (got #{arguments.length-1}, expected #{@paramCount} excluding callback)"
    async.map @_slots, (slot, iteratorCallback) ->
      slot args..., iteratorCallback
    , (error, slotsResults) =>
      if error?
        callback error, null
      else
        # Since the processor is not an async function, it's presumably allowed
        # to throw exceptions.
        try
          result = @processor slotsResults
        catch emissionError
        callback emissionError, result
    null

  @arrayControlSignal: (paramCount) ->
    ###
    Builds an "array" ControlSignal. This ControlSignal will provide
    all the slots' results in an array to the emission callback.

    See the ControlSignal constructor for more info.
    ###
    new ControlSignal paramCount, (slotsResults) -> slotsResults

  @vetoControlSignal: (paramCount) ->
    ###
    Builds a "veto" ControlSignal. The value provided to the emission callback
    is the result of performing a boolean AND operation against all the slots' results.

    See the ControlSignal constructor for more info.
    ###
    new ControlSignal paramCount, (slotsResults) ->
      slotsResults.every (x) -> x

  @voidControlSignal: (paramCount) ->
    ###
    Builds a "void" ControlSignal. This ControlSignal will always provide
    null to the emission callback.

    See the ControlSignal constructor for more info.
    ###
    new ControlSignal paramCount, -> null

module.exports = ControlSignal
