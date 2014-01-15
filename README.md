The ControlSignal provides a simple and special signal-slot implementation.
However, it should not be used to implement the Observer pattern per se
because it allows the creation of hooks that return values that influence
the owner's operations.

More information is available in the docs directory, which is generated by
running coffeedoc against the src directory. An
[online copy](http://htmlpreview.github.io/?https://github.com/mikesech/control-signal/blob/master/docs/src/ControlSignal.coffee.html)
is available.
