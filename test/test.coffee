assert = require 'assert'
async = require 'async'

ControlSignal = require 'ControlSignal'

describe 'ControlSignal', ->

  describe 'generic functionality', ->

    cs = undefined
    beforeEach -> cs = new ControlSignal 2, ->
    # processor is meaningless since we don't care about the results in this section

    describe 'constructor', ->
      it 'should throw if given an arity of less than -1', ->
        assert.doesNotThrow -> new ControlSignal -1
        assert.throws -> new ControlSignal -2

    describe 'empty', ->
      it 'should have no slots at first', ->
        assert.equal cs.slotCount(), 0
      it 'should return false when removing an unregistered specific slot', ->
        assert !cs.removeSlot(->), "should return false and do nothing else when removing unregistered slot"
      it 'should throw exception when adding slot too few parameters', ->
        assert.throws ->
          cs.addSlot (c) ->
      it 'should throw exception when adding slot too many parameters', ->
        assert.throws ->
          cs.addSlot (a,b,c) ->

    describe 'emission', ->
      slotFired = undefined
      slot = (flag, callback) ->
        slotFired = true
        callback null, flag
      beforeEach ->
        slotFired = false
        cs.addSlot slot

      it 'should have the correct slot count', ->
        assert.equal cs.slotCount(), 1
    
      it 'should fire slots when emitted', (done) ->
        cs.emit false, (error, results) ->
          assert.ifError error
          assert.ok slotFired
          done()

      it 'should throw if too few arguments given', ->
        assert.throws ->
          cs.emit done

      it 'should throw if too many arguments given', ->
        assert.throws ->
          cs.emit 0, 1, done

      it 'should not fire after slot is removed', (done) ->
        assert cs.removeSlot slot, "should return true when removing registered slot"
        cs.emit false, (error, results) ->
          assert.ifError error
          assert.ok !slotFired
          done()

      it 'should give callback an error if one slot erred', (done) ->
        originalError = new Error "hello"
        cs.addSlot (flag, callback) -> callback originalError
        assert.equal cs.slotCount(), 2
        cs.emit false, (error, results) ->
          assert.deepEqual error, originalError
          assert !results?, "results should be null if there is an error"
          done()

      it 'should give callback an error if the processor threw one', (done)->
        originalError = new Error "an error occurred"
        cs.processor = -> throw originalError
        cs.emit false, (error, results) ->
          assert.deepEqual error, originalError
          assert !results?, "results should be null if there is an error"
          done()

  describe 'ArrayControlSignal', ->

    cs = undefined
    beforeEach -> 
      cs = ControlSignal.arrayControlSignal 2    
      cs.addSlot (flag, callback) ->
        slotFired = true
        callback null, flag

    it 'should give callback array of all slots return values', (done) ->
      cs.addSlot (flag, callback) -> callback(null, "hello")
      assert.equal cs.slotCount(), 2
      cs.emit false, (error, results) ->
        assert.ifError error
        assert.deepEqual results, [false, "hello"]
        done()

  describe 'VetoControlSignal', ->

    describe 'no slots', ->
      cs = undefined
      beforeEach -> 
        cs = ControlSignal.vetoControlSignal 2    

      it 'should default to true', (done) ->
        cs.emit null, (error, result) ->
          assert.ifError error
          assert.ok result
          done()

    describe 'slots', ->
      cs = undefined
      beforeEach -> 
        cs = ControlSignal.vetoControlSignal 2    
        cs.addSlot (flag, callback) ->
          callback null, flag

      it 'should give the boolean AND of all the slot results', (done) ->
        async.series [
          (stepDone) ->
            cs.emit false, (error, result) ->
              assert.ifError error
              assert.equal result, false
              stepDone()
          (stepDone) ->
            cs.emit true, (error, result) ->
              assert.ifError error
              assert.equal result, true
              stepDone()
          (stepDone) ->
            cs.addSlot (flag, callback) ->
              callback null, true
            stepDone()
          (stepDone) ->
            cs.emit false, (error, result) ->
              assert.ifError error
              assert.equal result, false
              stepDone()
          (stepDone) ->
            cs.emit true, (error, result) ->
              assert.ifError error
              assert.equal result, true
              stepDone()
          (stepDone) ->
            cs.addSlot (flag, callback) ->
              callback null, false
            stepDone()
          (stepDone) ->
            cs.emit true, (error, result) ->
              assert.ifError error
              assert.equal result, false
              stepDone()
        ], done

  describe 'VoidControlSignal', ->

    describe 'no slots', ->
      cs = undefined
      beforeEach -> 
        cs = ControlSignal.voidControlSignal 2    

      it 'should result in null', (done) ->
        cs.emit null, (error, result) ->
          assert.ifError error
          assert.strictEqual result, null
          done()

    describe 'slots', ->
      cs = undefined
      beforeEach -> 
        cs = ControlSignal.voidControlSignal 2    
        cs.addSlot (flag, callback) ->
          callback null, flag

      it 'should result in null with one slot', (done) ->
        cs.emit true, (error, result) ->
          assert.ifError error
          assert.strictEqual result, null
          done()

      it 'should result in null with two slots', (done) ->
        cs.addSlot (flag, callback) ->
          callback null, flag
        cs.emit true, (error, result) ->
          assert.ifError error
          assert.strictEqual result, null
          done()

