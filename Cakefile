{ spawn, exec } = require 'child_process'

run = (cmd, args) ->
  proc = spawn cmd, args
  proc.stderr.pipe(process.stderr,{end: false})
  proc.stdout.pipe(process.stdout,{end: false})
  proc.on 'exit', (status) ->
    process.kill(1) if(status != 0)

task 'start', 'Start the app', ->
  run 'npm', ['install']
  run 'forever', ['start',
                  "--minUptime",'2000',
                  "--spinSleepTime","5000",
                  "--watch","--watchDirectory","#{__dirname}/lib",
                  "--append",
                  "-l","#{__dirname}/log/forever.log"
                  "#{__dirname}/lib/server.js"]

task 'stop', 'Stop the app', ->
  run 'forever', ['stop',"#{__dirname}/lib/server.js"]

task 'log', 'Tail forever log', ->
  run 'tail', ['-n','200','-f',"#{__dirname}/log/forever.log"]

task 'test', 'Run mocha tests', ->
  run 'node', ['node_modules/mocha/bin/mocha',
               '--colors',
               '--require', 'should',
               '--reporter', 'spec',
               '--compilers', 'coffee:coffee-script']
