mongo = require 'mongodb'
aws = require 'aws-sdk'
promise = require 'bluebird'
path = require 'path'
fs = require 'fs'
moment = require 'moment'
cp = require 'child_process'

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
    @db = new mongo.Db(dbOptions.db, new mongo.Server(dbOptions.host, dbOptions.port, {}), {w: 1})
    @dbConnect = promise.fromNode (cb) => @db.open(cb)

  dump: ([fileName]..., cb) ->
    @dbConnect
    .then () =>
      promise.try =>
        @dbOptions.collection && [@dbOptions.collection] || promise.fromNode (cb) => @db.collectionNames(cb)
    .each (collection) =>
      promise.try =>
        defer = promise.defer()
        args = ['--db', @dbOptions.db, '--collection', collection]
        if @dbOptions.host
          args = args.concat(['--host', @dbOptions.host])
        if @dbOptions.port
          args = args.concat(['--port', @dbOptions.port])
        args.push '-'
        mongodump = cp.spawn('mongodump', args)
        mongodump.output.pause()
        mongodump.on 'exit', -> defer.resolve(mongodump.output)
        mongodump.on 'error', (err) -> defer.reject(err)
        defer.promise
      .then (stream) =>
        stream.resume()
        promise.fromNode (callback) =>
          options =
            Bucket: @s3Options.bucket
            Key: "mongo_dump/#{moment().format('DDMMYY_HHmm')}/#{@dbOptions.db}/#{collection}.bson"
            ACL: 'private'
            Body: stream
            ContentType: 'binary/octet-stream'
          @s3Client.putObject(options, callback)
    .nodeify(cb)


module.exports = Backup