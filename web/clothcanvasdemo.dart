/*
Ported to dart by Adam Singer (financeCoding@gmail.com)

Copyright (c) 2013 lonely-pixel.com, Stuffit at codepen.io (http://codepen.io/stuffit)

View this and others at http://lonely-pixel.com

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
*/

import 'dart:html';
import 'dart:math' as Math;

// settings
var physics_accuracy = 6,
mouse_influence      = 20,
mouse_cut            = 8, // 5,
gravity              = 900,
cloth_height         = 70, // 30,
cloth_width          = 80, // 50,
start_y              = 20,
spacing              = 3, //7,
tear_distance        = 60;

class Mouse {
  bool down = false;
  num button = 1;
  num x = 0;
  num y = 0;
  num px = 0;
  num py = 0;
}

var canvas,
ctx,
cloth,
boundsx,
boundsy;
Mouse mouse = new Mouse();

void main() {
  canvas = query("#c");
  ctx = canvas.context2D;
  canvas.width = canvas.clientWidth;
  canvas.height = 376;

  canvas.onMouseDown.listen((MouseEvent e) {
    //print("e.button = ${e.button}");
    //mouse.button = e.button;
    mouse.px = mouse.x;
    mouse.py = mouse.y;

    var rect = canvas.getBoundingClientRect();
    mouse.x = e.client.x - rect.left;
    mouse.y = e.client.y - rect.top;
    mouse.down = true;
    e.preventDefault();
  });

  canvas.onMouseUp.listen((MouseEvent e) {
    mouse.down = false;
    e.preventDefault();
  });

  canvas.onMouseMove.listen((MouseEvent e) {
    mouse.px = mouse.x;
    mouse.py = mouse.y;
    var rect = canvas.getBoundingClientRect();
    mouse.x = e.client.x - rect.left;
    mouse.y = e.client.y - rect.top;
    e.preventDefault();
  });

  canvas.onContextMenu.listen((e) {
    e.preventDefault();
  });

  boundsx = canvas.width - 1;
  boundsy = canvas.height - 1;

  ctx.strokeStyle = 'rgba(222,222,222,0.6)';
  cloth = new Cloth();
  update(0);
}

class Point {
  var x;
  var y;
  var px;
  var py;
  var vx = 0;
  var vy = 0;
  var pin_x = null;
  var pin_y = null;
  var constraints = [];

  Point(x, y) {
    this.x = x;
    this.y = y;
    this.px = x;
    this.py = y;
  }

  update(num delta) {
    if (mouse.down) {

      var diff_x = this.x - mouse.x,
          diff_y = this.y - mouse.y,
          dist   = Math.sqrt(diff_x * diff_x + diff_y * diff_y);

      if (mouse.button == 1) {

        if(dist < mouse_influence) {
          this.px = this.x - (mouse.x - mouse.px) * 1.8;
          this.py = this.y - (mouse.y - mouse.py) * 1.8;
        }

      } else if (dist < mouse_cut) {
        this.constraints = [];
      }
    }

    this.add_force(0, gravity);

    delta *= delta;
    var nx = this.x + ((this.x - this.px) * 0.99) + ((this.vx / 2) * delta);
    var ny = this.y + ((this.y - this.py) * 0.99) + ((this.vy / 2) * delta);

    this.px = this.x;
    this.py = this.y;

    this.x = nx;
    this.y = ny;

    this.vy = this.vx = 0;
  }

  draw() {
    if (this.constraints.length <= 0) return;

    var i = this.constraints.length;

    while(i--> 0) {
      this.constraints[i].draw();
    }
  }

  resolve_constraints() {
    if (this.pin_x != null && this.pin_y != null) {

      this.x = this.pin_x;
      this.y = this.pin_y;
      return;
    }

    var i = this.constraints.length;
    while(i--> 0) this.constraints[i].resolve();

    if (this.x > boundsx) {
      this.x = 2 * boundsx - this.x;
    } else {
      if (1 > this.x) {
        this.x = 2 - this.x;
      }
    }

    if (this.y < 1) {
      this.y = 2 - this.y;
    } else {
      if (this.y > boundsy) {
        this.y = 2 * boundsy - this.y;
      }
    }
  }

  attach(point) {
    this.constraints.add(
        new Constraint(this, point)
    );
  }

  remove_constraint(lnk) {
    var i = this.constraints.length;
    while(i--> 0) {
      if(this.constraints[i] == lnk) {
        this.constraints.removeAt(i);
      }
    }
  }

  add_force(x, y) {

    this.vx += x;
    this.vy += y;
  }

  pin(pinx, piny) {
    this.pin_x = pinx;
    this.pin_y = piny;
  }
}

class Constraint {

  var p1;
  var p2;
  var length;

  Constraint(p1, p2) {
    this.p1 = p1;
    this.p2 = p2;
    this.length = spacing;
  }

  resolve() {
    var diff_x = this.p1.x - this.p2.x,
        diff_y = this.p1.y - this.p2.y,
        dist = Math.sqrt(diff_x * diff_x + diff_y * diff_y),
        diff = (this.length - dist) / dist;

    if (dist > tear_distance) {
      this.p1.remove_constraint(this);
    }

    var px = diff_x * diff * 0.5;
    var py = diff_y * diff * 0.5;

    this.p1.x += px;
    this.p1.y += py;
    this.p2.x -= px;
    this.p2.y -= py;
  }

  draw() {
    ctx.moveTo(this.p1.x, this.p1.y);
    ctx.lineTo(this.p2.x, this.p2.y);
  }
}

class Cloth {

  var points;

  Cloth() {
    this.points = [];

    var start_x = canvas.width / 2 - cloth_width * spacing / 2;

    for(var y = 0; y <= cloth_height; y++) {

      for(var x = 0; x <= cloth_width; x++) {

        var p = new Point(start_x + x * spacing, start_y + y * spacing);

        if (x != 0) {
          p.attach(this.points[this.points.length - 1]);
        }

        if (y == 0) {
          p.pin(p.x, p.y);
        }

        if (y != 0) {
          p.attach(this.points[x + (y - 1) * (cloth_width + 1)]);
        }

        this.points.add(p);

      }
    }
  }

  update() {
    var i = physics_accuracy;

    while(i--> 0) {
      var p = this.points.length;
      while(p--> 0) {
        this.points[p].resolve_constraints();
      }
    }

    i = this.points.length;
    while(i--> 0) {
      this.points[i].update(.016);
    }
  }

  draw() {
    ctx.beginPath();

    var i = cloth.points.length;
    while(i--> 0) {
      cloth.points[i].draw();
    }

    ctx.stroke();
  }
}

update(num _) {

  ctx.clearRect(0, 0, canvas.width, canvas.height);

  cloth.update();
  cloth.draw();

  //requestAnimFrame(update);
  window.requestAnimationFrame(update);
}