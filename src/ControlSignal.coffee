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
  the async slots. Instead, during construction, you must provide an iterator and
  initial value. These parameters are used to perform a reduce operation against
  the results from all the slot calls. Note that all slots calls are performed
  "in parallel" and then reduced synchronously thereafter.

  The ControlSignal provides some class functions that create special instances
  with built-in iterators.
  ###

  constructor: (@arity, @iterator, @initialValue) ->
    ###
    Constructs a new ControlSignal.

    ##\##\# Arguments
    `@arity`  
    The arity of the signal, including the callback parameter. For example,
    if the slots will take no parameters except for the callback, this should
    be 1. The number of parameters given to emit and the arity of the slots
    will be checked against this value; if they do not match, an exception
    will be thrown as soon as possible.

    There are two special values for this parameter. 0 indicates a varidaic signal;
    slots must declare no parameters (instead using the special arguments variable),
    and the signal will allow any number of parameters to be emitted. -1 disables
    all arity checking. This should be used with extreme caution since an arity mismatch
    will cause the callback to get lost and most likely cause the application to malfunction
    horribly.

    `@iterator`  
    The iterator function to be used to reduce all the results from the slots. This
    function is synchronous and matches the iterator used by `Array.prototype.reduce`.
    It is given four parameters, of which the last two are more or less irrelevant:
      * The previous value of the accumulator.
      * The current value being processed.
      * The index of the slot whose result is currently being processed.
      * The array of slot results currently being processed.

    `@initialValue`  
    The initial value used during the reduce stage. It is mandatory because it also functions
    as the default value provided to the emission callback when there are no slots.

    ##\##\# Exceptions
    Throws RangeError if the arity is less than -1.
    ###
    throw new RangeError "ControlSignal arity must be greater or equal to -1" if @arity < -1
    @_slots = []

  addSlot: (slot) ->
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
    is given to the emission callback depending on the signal's
    reduce iterator.

    The arity of the slot must match the arity of
    the signal. If the signal's arity is 0, then the slot must be
    variadic and declare no parameters. If the signal's arity is -1,
    all arity checking is disabled.

    ##\##\# Returns
    null

    ##\##\# Exceptions
    Throws Error if arity doesn't match signal's (see the definition of `slot`
    above).

    ###
    if slot.length != @arity && @arity >= 0
      throw new Error "slot's arity does not match signal's (#{slot.length} != #{@arity} including callback)"
    @_slots.push slot
    null

  removeSlot: (slot) ->
    ###
    Removes a given slot.

    If the slot was registered multiple times, only one
    registration will be removed. The slot will continue
    to be invoked by the other registrations.

    ##\##\# Arguments
    `slot`  
    The slot as provided to `addSlot`. Must be a function.

    ##\##\# Returns
    True if a slot was removed; false otherwise.
    ###
    for s, i in @_slots by -1
      if s == slot
        @_slots.splice(i, 1)
        return true
    false

  slotCount: ->
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
    be equal to the signal's arity *minus 1*.
    However, if the arity if 0 or -1 (indicating a variadic function or disabled
    checking, respectively), the number of arguments is not checked.

    `callback(error, value)`  
    The async callback. `error` will be the first error encountered
    or `null` if none were. The `value` will be the result of the
    reduce operation against all the slots' results unless there
    is an error, in which case it will be null.

    ##\##\# Returns
    This is an asynchronous function. The results are provided to the
    callback. However, the function itself returns null.

    ##\##\# Exceptions
    Throws Error if the number of arguments does not match the arity
    (see the definition of `args...` above).
    ###
    if arguments.length != @arity && @arity > 0
      throw new Error "incorrect number of arguments provided (got #{arguments.length}, expected #{@arity} including callback)"
    async.map @_slots, (slot, iteratorCallback) ->
      slot args..., iteratorCallback
    , (error, slotsResults) =>
      if error?
        callback error, null
      else
        # Since the iterator is not an async function, it's presumably allowed
        # to throw exceptions.
        try
          result = slotsResults.reduce @iterator, @initialValue
        catch emissionError
        callback emissionError, result
    null

  @arrayControlSignal: (arity) ->
    ###
    Builds an "array" ControlSignal. This ControlSignal will provide
    all the slots' results in an array to the emission callback.

    See the ControlSignal constructor for more info.
    ###
    new ControlSignal arity, (previousValue, currentValue) ->
      previousValue.concat [currentValue]
    , []

  @vetoControlSignal: (arity) ->
    ###
    Builds a "veto" ControlSignal. The value provided to the emission callback
    is the result of performing a boolean AND operation against all the slots' results.

    See the ControlSignal constructor for more info.
    ###
    new ControlSignal arity, (previousValue, currentValue) ->
      previousValue && currentValue
    , true

  @voidControlSignal: (arity) ->
    ###
    Builds a "void" ControlSignal. This ControlSignal will always provide
    null to the emission callback.

    See the ControlSignal constructor for more info.
    ###
    new ControlSignal arity, (-> null), null

module.exports = ControlSignal
