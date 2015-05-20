aws = require 'aws-sdk'
promise = require 'bluebird'
path = require 'path'
fs = require 'fs'
moment = require 'moment'
cp = require 'child_process'
rimraf = require 'rimraf'
targz = require 'tar.gz'

class Backup

  @create: (s3Options, dbOptions) ->
    new Backup(s3Options, dbOptions)

  ###
  @param [Object] options
  @option options [Object] s3 S3 config object
  @option options [Object] mongo S3 config object
  ###
  constructor: (@s3Options = {}, @dbOptions = {}, @targzOptions) ->
    @s3Client = new aws.S3(@s3Options)

  dump: ([fileName]..., cb) ->
    date = moment().format('DDMMYY_HHmm')
    promise.try =>
      dir = path.join(__dirname, 'tmp_dump_' + date)
      gzipFile = dir + '.tar.gz'
      args = ['--db', @dbOptions.db, '--out', dir]
      if @dbOptions.collection
        args = args.concat(['--collection', @dbOptions.collection])
      if @dbOptions.host
        args = args.concat(['--host', @dbOptions.host])
      if @dbOptions.port
        args = args.concat(['--port', @dbOptions.port])
      promise.fromNode (cb) ->
        mongodump = cp.exec('mongodump ' + args.join(' '), cb)
      .then =>
        promise.fromNode (cb) =>
          new targz(@targzOptions).compress(dir, gzipFile, cb)
      .then =>
        promise.fromNode (cb) =>
          options =
            Bucket: @s3Options.bucket
            Key: "mongo_dump/#{date}.tar.gz"
            ACL: 'private'
            Body: fs.createReadStream(gzipFile)
            ContentType: 'binary/octet-stream'
          @s3Client.putObject(options, cb)
      .then ->
        promise.fromNode (cb) -> rimraf(dir, cb)
      .then ->
        promise.fromNode (cb) -> rimraf(gzipFile, cb)
    .nodeify(cb)

module.exports = Backup