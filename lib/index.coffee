mongo = require 'mongodb'
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
  constructor: (@s3Options = {}, @dbOptions = {}) ->
    @s3Client = new aws.S3(@s3Options)
    @db = new mongo.Db(@dbOptions.db, new mongo.Server(@dbOptions.host, @dbOptions.port, {}), {w: 1})
    @dbConnect = promise.fromNode (cb) => @db.open(cb)

  dump: ([fileName]..., cb) ->
    date = moment().format('DDMMYY_HHmm')
    @dbConnect
    .then () =>
      promise.try =>
        @dbOptions.collection && [@dbOptions.collection] || promise.fromNode (cb) => @db.collectionNames(cb)
    .each (collection) =>
      promise.try =>
        dir = __dirname + 'tmp_dump_' + date
        gzipFile = dir + '.tar.gz'
        args = ['--db', @dbOptions.db, '--out', dir]
        if @dbOptions.collection
          args = args.concat(['--collection', collection.name])
        if @dbOptions.host
          args = args.concat(['--host', @dbOptions.host])
        if @dbOptions.port
          args = args.concat(['--port', @dbOptions.port])
        promise.fromNode (cb) ->
          mongodump = cp.exec('mongodump ' + args.join(' '), cb)
        .then ->
          promise.fromNode (cb) ->
            new targz().compress(dir, gzipFile, cb)
        .then =>
          options =
            Bucket: @s3Options.bucket
            Key: "mongo_dump/#{date}.tar.gz"
            ACL: 'private'
            Body: fs.createReadStream(gzipFile)
            ContentType: 'binary/octet-stream'
          @s3Client.putObject(options, callback)
        .then ->
          promise.fromNode (cb) -> rimraf(dir, cb)
        .then ->
          promise.fromNode (cb) -> rimraf(gzipFile, cb)
    .nodeify(cb)


module.exports = Backup