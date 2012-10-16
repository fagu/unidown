#!/usr/bin/ruby -w
# encoding: utf-8

require 'fileutils'
require 'digest/md5'
require 'optparse'
require 'ostruct'
require 'unijobss.rb'
require 'myfiledialog.rb'

module Util
	def Util.callerline(bt)
		bt.each do |c|
			if  c =~ /\A\(eval\):(\d+):/
				return $1.to_i
			end
		end
		return nil
	end
end

module JobIniter
end

class MatchedContext
	include JobIniter
	def initialize(x)
		@x = x
	end
	def x
		return @x
	end
	def p
		return @x.params
	end
	def method_missing(meth, *args)
		if    meth =~ /\As(\d+)\Z/
			return p[$1.to_i]
		elsif meth =~ /\Ai(\d+)\Z/
			return p[$1.to_i].to_i
		else
			super
		end
	end
end

class InternetLocation
	attr_accessor :url, :destdir
	def initialize(url, destdir, has = {}, &block)
		@caller = Kernel.caller
		@url = url
		@destdir = destdir
		@args = ["-N"]
		if has[:user]
			@args += ["--http-user=#{has[:user]}", "--http-password=#{has[:password]}"]
		end
		if !has[:onlyfile]
			@args += ["-np","-r"]
		end
		if has[:exclude]
			@args += ["-R", has[:exclude]]
		end
		if has[:excludedir]
			@args += ["-X", has[:excludedir]]
		end
		@args += ["-P",".downloads/#{@destdir}","#{@url}","-o",".downloads/#{@destdir}.log"]
		@matchers = []
		instance_eval(&block)
		$unikernel.locations.push(self)
	end
	def map(regexp, &pr)
		ma = Matcher.new(regexp)
		ma.doers.push pr
		@matchers.push ma
		return ma
	end
	def smap(regexp, str)
		return map(regexp) do
			y = x
			li = str.split(/\t+/)
			for i in li
				if i =~ /\Atitle\(([^)]*)\)\Z/
					t = $1
					y = y >> title(t.gsub('$s1',s1.to_s).gsub('$i1',i1.to_s).gsub('$s2',s2.to_s).gsub('$i2',i2.to_s))
				elsif i =~ /\Asave\(([^)]*)\)\Z/
					t = $1
					y = y >> save(t.gsub('$s1',s1.to_s).gsub('$i1',i1.to_s).gsub('$s2',s2.to_s).gsub('$i2',i2.to_s))
				elsif i =~ /\Aprint\Z/
					y = (y >> pr)
				else
					throw Exception.new("Error in config: #{i}")
				end
			end
			next y
		end
	end
	def add(str)
		str.each_line do |l|
			l.strip!
			p = l.split(/ {5,}/)
			if l != ''
				r = map(p[0]) do
					y = x
					if p[2] && p[2] != '-'
						y = y >> title(p[2].gsub('$s1',s1.to_s).gsub('$i1',i1.to_s).gsub('$s2',s2.to_s).gsub('$i2',i2.to_s))
					end
					if p[3] && p[3] != '-'
						y = y >> save(p[3].gsub('$s1',s1.to_s).gsub('$i1',i1.to_s).gsub('$s2',s2.to_s).gsub('$i2',i2.to_s))
					end
					if p[4] && p[4] != '-'
						y = y >> pr
					end
					next y
				end
				r = r # Um Warnung wegen unbenutzter Variablen zu vermeiden
				eval("$#{p[1]} = r") if p[1] && p[1] != '-'
			end
		end
	end
	def download(errmutex)
		FileUtils.mkpath ".downloads/#{@destdir}"
		if !Kernel.system("wget", *@args)
			errmutex.synchronize do
				$stderr.puts "Download to .downloads/#{@destdir} failed:"
				$stderr.puts "wget #{@args.join(' ')}"
			end
		end
	end
	def search(dir=nil)
		dir ||= ".downloads/#{@destdir}"
		Dir.new(dir).each do |ifi|
			next if ifi == "." || ifi == ".."
			fi = File.join(dir, ifi)
			if File.directory?(fi)
				search(fi)
			else
				fi = fi[".downloads/#{@destdir}/".length .. -1]
				gef = false
				@matchers.each do |mat|
					if mat.exp =~ "/"+fi
						ij = InJob.new(@destdir+"/"+fi, $~)
						mat.matched.push ij
						mat.ma[$~.captures] = ij
						gef = true
						break
					end
				end
				if !gef
					puts "Unbekannt: #{fi}"
					n = Notification.new("Unbekannt: #{fi}", Qt::Icon.fromTheme("document-preview"))
					n.choice("Hinzufügen") do
						MyFileDialog.new($mainwindow, self, fi)
						false
					end
					n.choice("Anzeigen") do
						system("xdg-open '.downloads/#{destdir}/#{fi}' > /dev/null 2> /dev/null &")
						false
					end
				end
			end
		end
	end
	def callall
		@matchers.each do |mat|
			mat.doers.each do |d|
				mat.matched.each do |x|
					res = MatchedContext.new(x).instance_eval(&d)
				end
			end
		end
	end
	def callerline
		Util.callerline(@caller)
	end
end

class ConfigEnv
	def configA(&pr)
		$unikernel.configA = pr
	end
	def configB(&pr)
		$unikernel.configB = pr
	end
end
class ConfigAEnv
	def loc(*args,&block)
		InternetLocation.new(*args,&block)
	end
end
class ConfigBEnv < ConfigAEnv
	include JobIniter
	def book(name)
		$unikernel.books[name]
	end
	def method_missing(meth, *args)
		if meth =~ /\Abook_(.+)\Z/
			return book($1)
		else
			super
		end
	end
end

class Matcher
	attr_accessor :exp
	attr_accessor :matched, :ma
	attr_accessor :doers
	def initialize(expstr)
		@exp = Regexp.new("\/"+expstr+"\\Z")
		@matched = []
		@ma = {}
		@doers = []
	end
end

require 'nokogiri'

class UnidownKernel
	attr_accessor :dodownload, :quiet, :remake, :unidir, :configA, :configB, :locations, :bookchapters, :books, :foundfile, :fatalerror
	def initialize
		@dodownload = true
		@quiet = true
		@remake = false
		@unidir = ENV['UNIDIR']
		@locations = []
		@bookchapters = {}
		@books = {}
		@foundfile = {}
		@fatalerror = false
	end
	def init
		@oldsavedfiles = []
		if File.exists?(".savedfiles")
			IO.readlines(".savedfiles").each do |fi|
				@oldsavedfiles.push fi.strip
			end
		end
		$stdout = File.open('unidown.log', 'a')
		$stderr = $stdout

		time = Time.now.to_s
		puts "### " + time + " " + "#"*(100-time.size)
		begin
			ConfigEnv.new.instance_eval(IO.read("config.rb"))
			ConfigAEnv.new.instance_eval(&@configA)
		rescue Exception => e
			rescueerror(e)
		end
	end
	def download
		return if @fatalerror
		if @dodownload
			threads = []
			errmutex = Mutex.new
			@locations.each do |loc|
				threads.push(Thread.new do
					loc.download(errmutex)
				end)
			end
			threads.each do |t|
				t.join
			end
		end
	end
	def findjobs
		return if @fatalerror
		@locations.each do |loc|
			loc.search
		end
		
		@locations.each do |loc|
			loc.callall
		end
		
		@bookchapters.each do |b,cs|
			cs.sort_by! {|c| c.cmp}
			j = PDFBookJob.new
			ct = []
			cs.each do |c|
				i = 0
				while i < ct.size && i < c.name.size && ct[i].name == c.name[i]
					i += 1
				end
				while ct.size > i
					ct.pop
				end
				if i == c.name.size
					ca = PDFBookProp.new(nil,c.job)
					if !ct.empty?
						ca >> ct.last
					else
						ca >> j
					end
				else
					while i < c.name.size
						ca = PDFBookProp.new(c.name[i])
						ca.job = c.job if i == c.name.size-1
						if !ct.empty?
							ca >> ct.last
						else
							ca >> j
						end
						ct.push ca
						i += 1
					end
				end
			end
			
			@books[b] = j
		end
		begin
			ConfigBEnv.new.instance_eval(&@configB)
		rescue Exception => e
			rescueerror(e)
		end
	end
	
	def runjobs
		return if @fatalerror
		FileUtils.mkpath ".mod"
		FileUtils.mkpath ".tmp"
		FileUtils.mkpath ".log"
		
		Dir.chdir(".mod") do
			Dir.new(".").each do |fi|
				@foundfile[fi] = false if fi != '.' && fi != '..'
			end
			Dir.new("../.log").each do |fi|
				@foundfile[fi] = false if fi != '.' && fi != '..'
			end

			Job.jobs.each do |job|
				job.run
			end

			@foundfile.each do |fi,fo|
				if !fo
					FileUtils.rm fi if File.exists? fi
					FileUtils.rm "../.log/"+fi if File.exists? "../.log/"+fi
				end
			end
		end
		
		SaveJob.savedfiles.each do |f,c|
			if c.size > 1
				puts "Mehrfachbelegung von #{f} (Zeilen #{c.map{|x|Util.callerline(x.caller).to_s}.join(', ')})"
				n = Notification.new("Mehrfachbelegung von #{f} (Zeilen #{c.map{|x|Util.callerline(x.caller).to_s}.join(', ')})", Qt::Icon.fromTheme("process-stop"))
				c.each_with_index do |x,i|
					n.choice("Konfiguration #{i+1}") do
						x.showconfig
						false
					end
				end
			end
		end
	end
	
	def finalize
		return if @fatalerror
		@oldsavedfiles.each do |fi|
			if !SaveJob.savedfiles[fi] && File.exists?(fi)
				puts "rm #{fi}"
				FileUtils.rm fi
			end
		end

		File.open(".savedfiles","w") do |sf|
			SaveJob.savedfiles.each do |fi,spam|
				sf.puts fi
			end
		end
		
		$stdout.flush
		$stderr.flush
		$stdout = STDOUT
		$stderr = STDERR
	end
	
	def rescueerror(e)
		File.open('config.log','w') do |f|
			f.puts e
			f.puts e.backtrace
		end
		bt = [e.message] + e.backtrace
		@fatalerror = true
		n = Notification.new("Fehler beim Ausführen der Konfigurationsdatei (Zeile #{Util.callerline(bt)})", Qt::Icon.fromTheme("process-stop"))
		n.choice("Logbuch anzeigen") do
			system("kate", 'config.log')
			false
		end
		n.choice("Konfiguration anzeigen") do
			system("kate", "-l", Util.callerline(bt).to_s, $unikernel.unidir+"/config.rb")
			false
		end
	end
end
