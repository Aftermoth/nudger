Minetest mod: nudger
----

* Rotates nodes in three dimensions using player-relative operations.

* Stores a node's absolute orientation and applies it other nodes.

* Cycles through nodes registered as alternative forms of a single functional node. For example, stairs may have straight, convex, and concave forms.


    nudger.register_transforms(
        string. Shared prefix of node names. Can be ''.
        table of strings. Node name remainders. Can include ''.
        integer. Tool wear in uses out of 255.
        function, called with (pos). Optional callback.
    )


* A fully orientable node is provided to clearly demonstrate the result of operations.


recipe:

    default:copper_ingot
    group:stick


----

Copyright (C) 2016 Aftermoth, Zolan Davis

This program is free software; you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation; either version 2.1 of the License,
or (at your option) version 3 of the License.

http://www.gnu.org/licenses/lgpl-2.1.html

