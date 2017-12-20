require 'socket'
require 'logger'
require 'date'
require 'open-uri'
require 'net/http'
require 'inifile'

class RainBot
  #constants / set up variables
  VERSION = '0.9'

  botIni = IniFile.load('config.ini')
  OAUTH = botIni['botinfo']['OAuth-key']
  NICKNAME = botIni['botinfo']['bot-nickname']

  def initialize(logger = nil)
    @logger = logger || Logger.new(STDOUT)
    @running = false
    @socket = nil
    @channelname = nil
    @messages = 0
    @commands = 0
  end

  def splitTraffic (s)
    #:username!username@username.tmi.twitch.tv PRIVMSG #twitchchannel :Hello World
    #<------------------Preamble-------------><command-><-Channel----><-msg------>
    s = s[1..s.length-1] #strip out first character
    splitstring = s.split(' ')
    out = []
    messagestart =  s.index(':')

    #preamble contains the name 3 times and 17 other characters
    namelength = (splitstring[0].length - 17) / 3
    out[0] = splitstring[0][0..namelength] #strip the name out of the preamble
    out[1] = s[(messagestart+1)..s.length-1]
    return out
  end

  #get channel and open socket
  def connect()
    @logger.info "ShipBot v#{VERSION} started"
    @logger.info('What twitch channel do you want to connect to?')
    @channelname = gets.chomp.downcase

    @logger.info('Preparing to connect...')
    @socket = TCPSocket.new('irc.chat.twitch.tv', 6667)
    @logger.info('Connected successfully')

    @logger.info('Authenticating...')
    @socket.puts("PASS #{OAUTH}")
    @socket.puts("NICK #{NICKNAME}")
    @logger.info('Successfully authenticated')

    @logger.info("Joining #{@channelname}...")
    @socket.puts('JOIN #' + @channelname)
    @logger.info("Joined #{@channelname}")

    @logger.info('Requesting permissions...')
    @socket.puts('CAP REQ :twitch.tv/membership')
    @logger.info('Permissions granted')
    puts "" #newline
  end

  def run()
    running = true

    #Main loop thread
    Thread.start do
      while (running) do
        line = ''
        traffic = IO.select([@socket]) #get socket traffic
        traffic[0].each do |s| #for each line
          line = s.gets.chomp #get the line

          #Removes join and unesscesscary lines from the console
          if line =~ /:.+!.+@.+\.tmi\.twitch\.tv PRIVMSG #.+ :.+/
            #outputs chat wsith stripping
            line = splitTraffic(line)
            print "#{line[0]}"
            print " "*(25 - line[0].length) #25 character padding
            puts ": #{line[1]}"
            @messages = @messages+1
          else
            puts line
          end

          #<--------Commands/Triggers-------->

          if line[1].downcase.include? "good bot"
            @socket.puts("PRIVMSG ##{@channelname} :Awh thanks <3")
          end

          if line[1].downcase =~ /!time.*/
            time = DateTime.now.strftime("%d/%m/%Y %H:%M")
            @socket.puts("PRIVMSG ##{@channelname} :The time in GMT is #{time}")
            @commands = @commands+1
          end

          if line[1].downcase =~ /!github.*/
            @socket.puts("PRIVMSG ##{@channelname} :My github repository can be found at https://github.com/SamWhale/ShipBot")
            @commands = @commands+1
          end

          if line[1].downcase =~ /!commands.*/
            @socket.puts("PRIVMSG ##{@channelname} :My commands can be found here https://github.com/SamWhale/ShipBot/blob/master/README.md")
          end

          if line[1].downcase =~ /!uptime.*/
            uri = URI("https://decapi.me/twitch/uptime?channel=#{@channelname}")
            text = Net::HTTP.get(uri)

            if text == "#{@channelname} is offline"
              @socket.puts("PRIVMSG ##{@channelname} :#{text}")
            else
              @socket.puts("PRIVMSG ##{@channelname} :#{@channelname} has been live for #{text}")
            end
          end
        end
      end
    end

    #console loop
    while (running) do
      command = gets.chomp

      if command == 'disconnect'
        running = false
      elsif command =~ /send .+/
        msg = command[5..(command.length-1)]
        @socket.puts("PRIVMSG ##{@channelname} :#{msg}")
      else
        @socket.puts(command)
      end
    end

    @logger.info 'RainprowBot closing...'
    @logger.info "#{@messages} messages read"
    @logger.info "#{@commands} commands read"
    @logger.info "RainprowBot closed."
  end
end

client = RainBot.new
quit = false

while quit == false
  client.connect
  client.run

  correctanswer = false
  while !correctanswer do
    puts 'Connect to another channel? (Y/N)'
    inp = gets
    if inp =~ /(n|N).*/
      correctanswer = true
      quit = true
    elsif inp =~ /(y|Y).*/
      correctanswer = true
    else
      puts 'Please answer (y/n)'
    end
  end
end
