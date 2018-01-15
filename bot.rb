require "socket"
require "inifile"
require "date"
require 'open-uri'
require 'net/http'

Thread.abort_on_exception=true

class Bot
  def reloadConfig
    @botIni = IniFile.load("config/config.ini")
    @commandsIni = IniFile.load("config/commands.ini")

    @oauth = @botIni["botinfo"]["OAuth-key"]
    @nickname = @botIni["botinfo"]["bot-nickname"]

    puts "[#{getTime}]: Config reloaded"
  end

  def initialize
    Struct.new("Message", :user, :message, :timestamp)

    @running = false
    @socket = nil
    @channelname = nil
    @messages = 0

    reloadConfig
  end

  def getTime
    "#{DateTime.now.strftime("%H:%M")}"
  end

  def splitTraffic (s)
    #:username!username@username.tmi.twitch.tv PRIVMSG #twitchchannel :Hello World
    #<------------------Preamble-------------><command-><-Channel----><----msg---->

    out = Struct::Message.new

    #Stripping
    s = s[1..s.length-1] #strip out first colon
    splitstring = s.split(" ") #split string into 4 sections based on the spaces
    messagestart =  s.index(":") + 1 #Find start of the message itself

    #preamble contains the name 3 times and 17 other characters
    namelength = (splitstring[0].length - 17) / 3

    #Setting up the output
    out.user = splitstring[0][0..namelength]
    out.message = s[(messagestart)..s.length-1]
    out.timestamp = getTime

    return out
  end

  #get channel and open socket
  def connect()
    puts "[#{getTime}]: Ship Bot started"
    puts "[#{getTime}]: What twitch channel do you want to connect to?"
    @channelname = gets.chomp.downcase

    puts "[#{getTime}]: Preparing to connect..."
    @socket = TCPSocket.new("irc.chat.twitch.tv", 6667)
    puts "[#{getTime}]: Connected successfully"

    puts "[#{getTime}]: Authenticating..."
    @socket.puts("PASS #{@oauth}")
    @socket.puts("NICK #{@nickname}")
    puts "[#{getTime}]: Successfully authenticated"

    puts "[#{getTime}]: Joining #{@channelname}..."
    @socket.puts("JOIN #" + @channelname)
    puts "[#{getTime}]: Joined #{@channelname}"

    puts "[#{getTime}]: Requesting permissions..."
    @socket.puts("CAP REQ :twitch.tv/membership")
    puts "[#{getTime}]: Permissions granted"
    puts "" #newline
  end

  def addCommand(call, response)
    File.open('config/commands.ini', 'a') do |f|
      f.puts("#{call}=#{response}")
    end

    reloadConfig
  end

  def filterCommand(addCommString)
    splitMessage = addCommString.split(" ")
    call = splitMessage[2]
    responseArr = splitMessage[3..splitMessage.length-1]
    response = ""

    responseArr.each do |word|
      response.concat(word + " ")
    end

    response = response[0..response.length-1]

    addCommand(call, response)
  end

  def triggerCommands(line)
    m = line.message.downcase

    if m.include? "good bot"
      @socket.puts("PRIVMSG ##{@channelname} :Awh thanks <3")

    elsif m =~ /!rtd.*/
      if m =~ /!rtd [1-9][0-9]+/
        num = m[5..m.length-1].to_i
        randNum = (rand(num) + 1).to_s
      else
        randNum = (rand(6) + 1).to_s
      end
      @socket.puts("PRIVMSG ##{@channelname} :You rolled #{randNum}")
    elsif m =~ /!time.*/
      time = DateTime.now.strftime("%d/%m/%Y %H:%M")
      @socket.puts("PRIVMSG ##{@channelname} :The time in GMT is #{time}")

    elsif m =~ /!game.*/
      @socket.puts("PRIVMSG ##{@channelname} :The current game is #{Net::HTTP.get('decapi.me', "/twitch/game/#{@channelname}")}")

    elsif m =~ /!uptime.*/
      text = Net::HTTP.get('decapi.me', "/twitch/uptime?channel=#{@channelname}")
      if text == "#{@channelname} is offline"
        @socket.puts("PRIVMSG ##{@channelname} :#{text}")
      else
        @socket.puts("PRIVMSG ##{@channelname} :#{@channelname} has been live for #{text}")
      end

    elsif m =~ /!command add .+ .+/
      filterCommand(m)
      @socket.puts("PRIVMSG ##{@channelname} :Command added.")

    else
      #Commands from commands.ini
      @commandsIni["commands"].each_key do |command|
        if line.message.downcase =~ /#{command}.*/
          @socket.puts("PRIVMSG ##{@channelname} :#{@commandsIni["commands"][command]}")
        end
      end

    end

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
            puts "[#{line.timestamp}] #{line.user}#{" "*(25 - line.user.length)}:#{line[1]}"

            #Run against command patterns
            triggerCommands(line)

            @messages += 1
          elsif line == "PING :tmi.twitch.tv"
            @socket.puts("PONG :tmi.twitch.tv")
            puts "\n[#{getTime}] INFO - Ping recieved. Pong sent.\n"
          end

        end

      end
    end

    #quit loop
    while running do
      $command = gets
      if $command =~ /disconnect|dc/
        running = false
      elsif $command =~ /send .*/
        @socket.puts("PRIVMSG ##{@channelname} :#{$command.gsub("send ", "")}")
      end
    end

    messageReader.kill

    puts "[#{getTime}] Ship Bot closing..."
    puts "[#{getTime}] #{@messages} messages read"
    puts "[#{getTime}] Ship Bot closed."
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
