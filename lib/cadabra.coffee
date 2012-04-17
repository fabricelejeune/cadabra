fs = require("fs")
url = require("url")
uri = require("open-uri")
temp = require("temp")
log = require("util").log
pump = require("util").pump
exec = require("child_process").exec
normalize = require("path").normalize

String::camelize = ->
  this.replace /-+(.)?/g, (match, chr) ->
    if chr? then chr.toUpperCase() else ""

String::contains = (searchValue) ->
  this.indexOf(searchValue) != -1

String::extname = ->
  i = this.lastIndexOf "."
  if i < 0 then "" else this.substr(i+1)

String::strip = ->
  this.replace(/^\s+/, '').replace(/\s+$/, '')

class Cadabra
  self = @
  MOGRIFY_PATH = "mogrify"
  MOGRIFY_COMMANDS = "adaptive-blur adaptive-resize adaptive-sharpen adjoin affine alpha annotate antialias append authenticate auto-gamma auto-level auto-orient background bench iterations bias black-threshold blue-primary blue-shift blur border bordercolor brightness-contrast caption cdl channel charcoal chop clip clamp clip-mask clip-path clone clut contrast-stretch coalesce colorize color-matrix colors colorspace combine comment compose composite compress contrast convolve coefficients crop cycle decipher debug define deconstruct delay delete density depth despeckle direction dissolve display dispose distort dither draw edge emboss encipher encoding endian enhance equalize evaluate evaluate-sequence extent extract family fft fill filter flatten flip floodfill flop font format frame function fuzz fx gamma gaussian-blur geometry gravity green-primary help identify ifft implode insert index intent interlace interline-spacing interpolate interword-spacing kerning label lat layers level limit linear-stretch liquid-rescale log loop mask mattecolor median modulate monitor monochrome morph morphology motion-blur negate noise normalize opaque ordered-dither orient page paint ping pointsize polaroid posterize precision preview print process profile quality quantize quiet radial-blur raise random-threshold red-primary regard-warnings region remap render repage resample resize respect-parentheses roll rotate sample sampling-factor scale scene seed segments selective-blur separate sepia-tone set shade shadow sharpen shave shear sigmoidal-contrast size sketch solarize splice spread strip stroke strokewidth stretch style swap swirl texture threshold thumbnail tile tile-offset tint transform transparent transparent-color transpose transverse treedepth trim type undercolor unique-colors units unsharp verbose version view vignette virtual-pixel wave weight white-point white-threshold write".split " "
  IDENTIFY_PATH = "identify"

  @version = "0.0.1"

  class @Image
    constructor: (@path, @tempfile = null) ->
      @args = []

    @open: (file_or_url, callback) ->
      self = @

      if file_or_url.contains "://" 
        ext = url.parse(file_or_url).pathname.extname()
      else
        ext = file_or_url.extname()

      uri file_or_url, (err, data) ->
        if !err
          temp.open {prefix: "cadabra", suffix: ".#{ext}"}, (err, info) ->
            if !err
              fs.write info.fd, data, 0, data.length, null, (err, written, buffer) ->
                if !err
                  self.create info.path, info.fd, err, callback
                else
                  callback err, null
            else
              callback err, null
        else
          callback err, null
      return

    @create: (@path, @tempfile = null, err = null, callback = null) ->
      img = new @(@path, @tempfile)
      callback err, img if callback
      return

    for command in MOGRIFY_COMMANDS
      do (command) ->
        Image.prototype[command.camelize()] = (params...) ->
          @args.unshift "-#{command} #{params.join(" ") if params}"
          @

    @::write = (out, callback) ->
      self = @
      if @args.length > 0
        cmd = new CommandBuilder MOGRIFY_PATH, @args.shift(), @path
        run cmd, (err, stdout, stderr) ->
          if !err
            self.write out
          else
            callback err if callback
      else
        write = fs.createWriteStream out
        read = fs.createReadStream @path
        write.once "open", (fd) ->
            pump read, write

    @::identify = (value, callback) ->
      switch true
        when /colorspace/.test value then cmd = new CommandBuilder IDENTIFY_PATH, "-quiet", "-format", format_option("%r"), normalize(@path)
        when /format/.test value then cmd = new CommandBuilder IDENTIFY_PATH, "-quiet", "-format", format_option("%m"), normalize(@path)
        when /width/.test value then cmd = new CommandBuilder IDENTIFY_PATH, "-quiet", "-format", format_option("%w"), normalize(@path)
        when /height/.test value then cmd = new CommandBuilder IDENTIFY_PATH, "-quiet", "-format", format_option("%h"), normalize(@path)
        when /dimensions/.test value then cmd = new CommandBuilder IDENTIFY_PATH, "-quiet", "-format", format_option("%w %h"), normalize(@path)
        when /^EXIF\:/i.test value then cmd = new CommandBuilder IDENTIFY_PATH, "-quiet", "-format", "\"%[#{value}]\"", normalize(@path)
        else cmd = new CommandBuilder IDENTIFY_PATH, "\"#{value}\"", normalize(@path)
      
      run cmd, {timeout: 120000}, (err, result) ->
        if !err
          result = result.split("\n")[0]
        callback err, result if callback

    format_option = (format) ->
      if !!process.platform.match /^win/ then "\"#{format}\\n\"" else "\"#{format}\\\\n\""

    run = (command_builder) ->
      command = command_builder.command
      options =
        encoding: "utf8"
        timeout: 0
        maxBuffer: 500*1024
        killSignal: "SIGKILL"

      if typeof arguments[1] == "object"
        keys = Object.keys options
        options[k] = arguments[1][k] for k, i in keys when arguments[1][k]?

      callback = arguments[arguments.length-1];
      callback = null if typeof callback != "function"

      log "running command: #{command}"
      child = exec command, options, (err, stdout, stderr) ->
        callback err, stdout, stderr if callback

    parseIdentify = (input) ->
      lines = input.split("\n")
      prop = {}
      props = [prop]
      lines.shift
      for currentLine, i in lines
        do (currentLine) ->
          if currentLine.length > 0
            indent = currentLine.search(/\S/)
            comps = currentLine.split(": ")
            indents.push indent if indent > prevIndent
            while indent < prevIndent
              indents.pop()
              prop = props.pop()
              prevIndent = indents[indents.length - 1]
            
            if comps.length < 2
              props.push prop
              prop = prop[currentLine.split(":")[0].trim().toLowerCase()] = {};
            else
              prop[comps[0].trim().toLowerCase()] = comps[1].trim()

            prevIndent = indent;
      props[0]

class CommandBuilder 
  constructor: (command, args...) ->
    args.unshift "-ping" if command == "identify"
    @command = "#{command} #{args.join(" ")}".strip()

module.exports = Cadabra