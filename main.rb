require "socket"
require "inifile"
require "date"
require 'open-uri'
require 'net/http'

Thread.abort_on_exception=true

class Bot
  #constants / set up variables

  botIni = IniFile.load("config.ini")
  OAUTH = botIni["botinfo"]["OAuth-key"]
  NICKNAME = botIni["botinfo"]["bot-nickname"]

  def initialize
    @running = false
    @socket = nil
    @channelname = nil
    @messages = 0
    Struct.new("Message", :user, :message)
  end

  def getTime
    "[#{DateTime.now.strftime("%H:%M")}]"
  end

  def splitTraffic (s)
    #:username!username@username.tmi.twitch.tv PRIVMSG #twitchchannel :Hello World
    #<------------------Preamble-------------><command-><-Channel----><----msg---->

    #Stripping
    s = s[1..s.length-1] #strip out first character
    splitstring = s.split(" ")
    out = Struct::Message.new
    messagestart =  s.index(":")

    #preamble contains the name 3 times and 17 other characters
    namelength = (splitstring[0].length - 17) / 3
    out.user = splitstring[0][0..namelength] #strip the name out of the preamble
    out.message = s[(messagestart+1)..s.length-1]
    return out
  end

  #get channel and open socket
  def connect()
    puts "#{getTime}: Ship Bot started"
    puts "#{getTime}: What twitch channel do you want to connect to?"
    @channelname = gets.chomp.downcase

    puts "#{getTime}: Preparing to connect..."
    @socket = TCPSocket.new("irc.chat.twitch.tv", 6667)
    puts "#{getTime}: Connected successfully"

    puts "#{getTime}: Authenticating..."
    @socket.puts("PASS #{OAUTH}")
    @socket.puts("NICK #{NICKNAME}")
    puts "#{getTime}: Successfully authenticated"

    puts "#{getTime}: Joining #{@channelname}..."
    @socket.puts("JOIN #" + @channelname)
    puts "#{getTime}: Joined #{@channelname}"

    puts "#{getTime}: Requesting permissions..."
    @socket.puts("CAP REQ :twitch.tv/membership")
    puts "#{getTime}: Permissions granted"
    puts "" #newline
  end

  def run()
    running = true

    #Get messages and display them
    messageReader = Thread.new do
      while (running) do
        line = ""
        traffic = IO.select([@socket]) #get socket traffic
        traffic[0].each do |s| #for each line
          line = s.gets #get the line
          if line != nil
            line = line.chomp
          end

          #Reads only chat messages
          if line =~ /:.+!.+@.+\.tmi\.twitch\.tv PRIVMSG #.+ :.+/
            #outputs chat wsith stripping
            line = splitTraffic(line)
            puts "#{getTime} #{line.user}#{" "*(25 - line.user.length)}:#{line[1]}"
            @messages += 1
          elsif line == "PING :tmi.twitch.tv"
            @socket.puts("PONG :tmi.twitch.tv")
            puts "\n#{getTime} INFO - Ping recieved. Pong sent.\n"
          end

          if line[1].downcase.include? "good bot"
            @socket.puts("PRIVMSG ##{@channelname} :Awh thanks <3")
          end

          if line[1].downcase =~ /!time.*/
            time = DateTime.now.strftime("%d/%m/%Y %H:%M")
            @socket.puts("PRIVMSG ##{@channelname} :The time in GMT is #{time}")
          end

          if line[1].downcase =~ /!github.*/
            @socket.puts("PRIVMSG ##{@channelname} :My github repository can be found at https://github.com/SamWhale/ShipBot")
          end

          if line[1].downcase =~ /!commands.*/
            @socket.puts("PRIVMSG ##{@channelname} :My commands can be found here https://github.com/SamWhale/ShipBot/blob/master/README.md")
          end

          if line[1].downcase =~ /!uptime.*/
            text = Net::HTTP.get('decapi.me', "/twitch/uptime?channel=#{@channelname}")

            if text == "#{@channelname} is offline"
              @socket.puts("PRIVMSG ##{@channelname} :#{text}")
            else
              @socket.puts("PRIVMSG ##{@channelname} :#{@channelname} has been live for #{text}")
            end
          end

        end

      end
    end

    #Get user input
    userinputCheck = Thread.new do
      $command = gets
    end

    #quit loop
    while running do
      if $command =~ /disconnect|dc/
        running = false
      end
      sleep(0.25)
    end

    userinputCheck.kill
    messageReader.kill

    puts "#{getTime} Ship Bot closing..."
    puts "#{getTime} #{@messages} messages read"
    puts "#{getTime} Ship Bot closed."
  end
end

client = Bot.new
quit = false

while quit == false
  client.connect
  client.run

  correctanswer = false
  while !correctanswer do
    puts "Connect to another channel? (Y/N)"
    inp = gets
    if inp =~ /(n|N).*/
      correctanswer = true
      quit = true
    elsif inp =~ /(y|Y).*/
      correctanswer = true
    else
      puts "Please answer (y/n)"
    end
  end
end
