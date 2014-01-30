[![build status](https://secure.travis-ci.org/fabricelejeune/cadabra.png)](http://travis-ci.org/fabricelejeune/cadabra)
# Cadabra

Cadabra is a NodeJS wrapper for ImageMagick using the mogrify command line program. The module is inspired by Ruby's [MiniMagick](https://github.com/probablycorey/mini_magick) library.

## Installation

```bash
$ npm install cadabra
```

## Usage

```javascript
var cadabra = require("cadabra")
cadabra.Image.open("input.jpg", function(err, image) {
  if(!err) {
    image.resize("100x100").write("output.jpg")
  }
})
```

[![Bitdeli Badge](https://d2weczhvl823v0.cloudfront.net/fabricelejeune/cadabra/trend.png)](https://bitdeli.com/free "Bitdeli Badge")

