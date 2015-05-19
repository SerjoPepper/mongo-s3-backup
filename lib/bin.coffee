backup = require('./index')
argv = require('yargs')
  .demand(['accessKeyId', 'secretAccessKey', 'bucket'])
  .usage('Usage: $0 <command> [options]')
  .describe('endpoint', 'endpoint')
  .describe('accessKeyId', 'accessKeyId')
  .describe('secretAccessKey', 'secretAccessKey')
  .describe('bucket', 'bucket')
  .describe('mongoHost', 'mongoHost')
  .describe('mongoPort', 'mongoPort')
  .describe('mongoDb', 'mongoDb')
  .describe('mongoCollection', 'mongoCollection')
  .descript('dumpDir', 'dumpDir')
  .alias('a', 'accessKeyId')
  .alias('s', 'secretAccessKey')
  .alias('b', 'bucket')
  .help('h')
  .argv

mongoOptions = {
  port: argv.mongoPort
  host: argv.mongoHost
  db: argv.mongoDb
  collection: mongoCollection
}

s3Options = {
  accessKeyId: argv.accessKeyId
  secretAccessKey: argv.secretAccessKey
  bucket: argv.bucket
  endpoint: argv.endpoint
}

backup.create(s3Options, mongoOptions).dump argv.dumpDir, (err) ->
  if (err)
    console.error(err)
    process.exit(1)
  else
    console.log('data dumped succesfully')
    process.exit(0)
