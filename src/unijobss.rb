# encoding: utf-8

require 'dbus'

module UniJobsUtil
	def UniJobsUtil.rc(*args)
		puts("cmd: "+args.join(" "))
		return Kernel.system(*args)#,:out=>$stdout,:err=>$stderr)
	end
end

module Asker
	def self.ask(question, answers)
		retval = 0
		if ENV["DISPLAY"]
			typ = nil
			if answers.size <= 1
				typ = "--msgbox"
			elsif answers.size == 2
				typ = "--yesno"
			elsif answers.size == 3
				typ = "--yesnocancel"
			end
			system("kdialog",typ,question)
			retval = 1+$?.exitstatus
		end
		return retval
	end
end

class Choice < Qt::Object
	attr_accessor :name, :func, :notification, :dir
	slots :run
	def initialize(name,func,notification)
		super(nil)
		@name = name
		@func = func
		@notification = notification
		@dir = Dir.pwd
	end
	def run
		Dir.chdir(@dir) do
			if func.call
				@notification.doclose
			end
		end
	end
end

class Notification < Qt::Object
	@@notifications = []
	def self.alll
		return @@notifications
	end
	attr_accessor :title, :choices
	signals 'beforeclose(int)', :afterclose
	def initialize(title)
		super(nil)
		@title = title
		@choices = []
		@@notifications.push self
	end
	def choice(name, &func)
		@choices.push Choice.new(name,func,self)
	end
	def doclose
		i = @@notifications.index(self)
		emit beforeclose(i)
		@@notifications.delete(self)
		emit afterclose()
	end
end

class Job
	@@jobs = []
	@@jobsbytype = {}
	def self.jobs
		@@jobs
	end
	def self.jobsbytype
		@@jobsbytype
	end
	attr_accessor :children
	attr_accessor :outfile
	attr_accessor :success
	def initialize
		@children = []
		@caller = Kernel.caller
		@success = false
		@tried = false
		@@jobs.push self
# 		puts self
		@@jobsbytype[self.class] ||= []
		@@jobsbytype[self.class].push self
	end
	def callerline
		@caller.each do |c|
			puts c
			if c =~ /\A\(eval\):(\d+):in `block (\(\d+ levels\) |)in init'/
				return $1
			end
		end
		return nil
	end
	def showconfig
		system("kate", "-l", callerline, $unikernel.unidir+"/config.rb")
	end
	def run
		return if @tried
		@tried = true
		initchildren
		@success = true
		@children.each do |ch|
			ch.run
			if !ch.success
				@success = false
			end
		end
		genout
		if $unikernel.remake && !self.kind_of?(PrintJob)
			FileUtils.rm(@outfile) if File.exists?(@outfile)
		end
		change = (!@outfile || !File.exist?(@outfile))
		if change && @success
			spec = "    Run #{self.class} => #{@outfile}"
			spec += " "*(100-spec.length)
			print spec
			ao = $stdout
			ae = $stderr
			begin
				$stdout = File.open("../.log/#{@outfile}","w")
				$stderr = $stdout
				STDOUT.reopen($stdout)
				STDERR.reopen($stderr)
				puts "#{self.class}: #{(@children.map { |ch| ch.outfile }).join ", "} => #{@outfile} initialized from"
				for c in @caller
					puts "    "+c
				end
				rrun
			rescue Exception => e
				@success = false
				puts e
				puts e.backtrace
				$stdout = ao
				$stderr = ae
				puts "[INTERNAL ERROR]"
				n = Notification.new("Interner Fehler bei #{self.class} (Zeile #{callerline}, => #{@outfile})")
				n.choice("Logbuch anzeigen") do
					system("kate", "../.log/#{@outfile}")
					false
				end
				n.choice("Konfiguration anzeigen") do
					showconfig
				end
			else
				$stdout = ao
				$stderr = ae
				FileUtils.rm Dir.glob("../.tmp/*")
				if @success
					puts "[OK]"
				else
					puts "[FAILED]"
					n = Notification.new("Interner Fehler bei #{self.class} (Zeile #{callerline}, => #{@outfile})")
					n.choice("Logbuch anzeigen") do
						system("kate", "../.log/#{@outfile}")
						false
					end
					n.choice("Konfiguration anzeigen") do
						showconfig
						false
					end
				end
			end
			$stdout.flush
		end
		if !@success
			FileUtils.rm @outfile if File.exist? @outfile
		end
		$unikernel.foundfile[@outfile] = true
	end
	def genout
		bla = ggenout
		bla = "#{self.class}\n"+@children.map{|c|c.outfile}.join("\n")+"\n#{bla}"
		@outfile = Digest::MD5.hexdigest(bla)
	end
	def initchildren
	end
	def >>(x)
		if x.kind_of?(Job)
			x.children.push self
			if x.kind_of?(PrintJob) || x.kind_of?(SaveJobInner)
				return self
			end
		else
			x.job = self
			return self
		end
		return x
	end
end

class InJob < Job
	#@devel = rand(1000000)
	attr_accessor :infile
	attr_accessor :params
	attr_accessor :i1, :i2
	def initialize(infile, params)
		super()
		@infile = infile
		@params = params
		@i1 = params[1].to_i
		@i2 = params[2].to_i
	end
	def ggenout
		return Digest::MD5.file("../.downloads/"+@infile).hexdigest
	end
	def rrun
		puts "  In #{@infile}"
		altst = File.join("../.alt",@infile)
		FileUtils.mkpath File.dirname(altst)
		nr = 1
		while File.exist?("#{altst}.#{nr}")
			nr += 1
		end
		if nr == 1
			@altfile = "#{altst}.#{nr}"
		else
			nr -= 1
			if FileUtils.cmp("#{altst}.#{nr}", "../.downloads/"+@infile)
				@altfile = "#{altst}.#{nr}"
			else
				nr += 1
			end
			@altfile = "#{altst}.#{nr}"
		end
		FileUtils.cp("../.downloads/"+@infile, @outfile)
		FileUtils.cp("../.downloads/"+@infile, @altfile)
	end
end

class SaveJob < Job
	@@savedfiles = {}
# 	@devel = rand(1000000)
	attr_accessor :realoutfile, :printjobs, :chapterprops
	def initialize(outfile)
		super()
		@realoutfile = outfile
		@printjobs = []
		@chapterprops = []
	end
	def ggenout
		if @@savedfiles[@realoutfile] == true
			puts "Doppelbelegung von #{@realoutfile}"
		end
		@@savedfiles[@realoutfile] = true
		if !File.exist?("../"+@realoutfile) && File.exist?(@outfile)
			FileUtils.rm(@outfile)
		end
		return @realoutfile
	end
	def rrun
		FileUtils.mkdir File.dirname("../"+@realoutfile) if !File.directory? File.dirname("../"+@realoutfile)
		FileUtils.cp(@children[0].outfile,"../"+@realoutfile)
		FileUtils.ln(@children[0].outfile,@outfile)
	end
	def self.savedfiles
		@@savedfiles
	end
end
class SaveJobInner < Job
	def initialize()
		super()
	end
	def ggenout
		return ""
	end
	def rrun
		ro = @children[0].realoutfile
		n = Notification.new("Geändert: #{ro}")
		n.choice("Anzeigen") do
			system("xdg-open '#{"../"+ro}' > /dev/null 2> /dev/null &")
			FileUtils.ln(@children[0].outfile,@outfile)
			true
		end
		n.choice("Ignorieren") do
			FileUtils.ln(@children[0].outfile,@outfile)
			true
		end
	end
end
module JobIniter
	def save(x, notify=true)
		j = SaveJob.new(x)
		if notify
			j = j >> SaveJobInner.new
		end
		return j
	end
end

class PDFBookProp
	#@devel = rand(1000000)
	attr_accessor :name
	attr_accessor :job
	attr_accessor :props
	attr_accessor :cmp
	def initialize(name, job = nil)
		@name = name
		@job = job
		@props = []
	end
	def >>(x)
		if x.kind_of?(PDFBookJob) || x.kind_of?(PDFBookProp)
			x.props.push self
		else
			x.children.push @job
		end
		return x
	end
	def ggenouthelper
		@job.chapterprops.push self if @job.kind_of?(SaveJob)
		erg = ""
		erg += @name if @name
		erg += "\n"
		erg += @job.outfile if @job
		erg += "\n"
		@props.each do |ch|
			erg += ch.ggenouthelper
		end
		erg += "\n"
	end
	def write(file, page, level)
		file.puts "\t"*level+"#{@name}/#{page}" if @name
		page += countpages(@job.outfile) if @job
		@props.each do |ch|
			page = ch.write(file, page, level+1)
		end
		return page
	end
	def countpages(pdf)
		if !(/NumberOfPages: (\d+)/ =~ `pdftk #{pdf} dump_data`)
			puts "Error determining page count of '#{pdf}'"
			return nil
		end
		return $1.to_i
	end
end
module JobIniter
	def ch(cmp,name,book)
		if name.kind_of?(String)
			name = [name]
		end
		c = PDFBookProp.new(name)
		c.cmp = cmp
		$unikernel.bookchapters[book] = [] if !$unikernel.bookchapters[book]
		$unikernel.bookchapters[book].push c
		return c
	end
end

class PDFBookJob < Job
# 	@devel = rand(1000000)
	attr_accessor :props
	def initialize()
		super()
		@props = []
	end
	def initchildren
		@children = []
		pdfs.each do |pd|
			@children.push pd
		end
	end
	def ggenout
		erg = ""
		@props.each do |pr|
			erg += pr.ggenouthelper
		end
		return erg
	end
	def rrun
		names = []
		@children.each do |c|
			na = "../.tmp/tmp#{names.size}.pdf"
			FileUtils.cp(c.outfile, na)
			names.push na
		end
# 		names = pdfs.map {|x| x.outfile }
		if !UniJobsUtil::rc("pdftk", *names, "cat", "output", "../.tmp/book.pdf")
# 		if !UniJobsUtil::rc("pdfjam", "--outfile", "../.tmp/book.pdf", *namen)
			@success = false
		end
		File.open("../.tmp/bookmarks.txt", "w") do |f|
			page = 1
			@props.each do |pr|
				page = pr.write(f, page, 0)
			end
		end
		if !UniJobsUtil::rc("jpdfbookmarks_cli", "../.tmp/book.pdf", "-a", "../.tmp/bookmarks.txt", "-o", @outfile, "-f")
			@success = false
		end
	end
	def pdfs
		res = []
		@props.each do |pr|
			res += vis(pr)
		end
		return res
	end
	def vis(pr)
		res = []
		res.push pr.job if pr.job
		pr.props.each do |ch|
			res += vis(ch)
		end
		return res
	end
	def flatten
		nprops = []
		@props.each do |pr|
			nprops += pr.props
		end
		@props = nprops
		return self
	end
end

class PDFTitleJob < Job
	#@devel = rand(1000000)
	def initialize(title)
		super()
		@title = title
	end
	def ggenout
		return @title
	end
	def rrun
		File.open("../.tmp/info.txt", "w") do |f|
			f.puts "InfoKey: Title"
			f.puts "InfoValue: #{@title}"
		end
		repaired = false
		FileUtils.cp(@children[0].outfile, "../.tmp/tmp.pdf")
		while true
			if UniJobsUtil::rc("pdftk", "../.tmp/tmp.pdf", "update_info_utf8", "../.tmp/info.txt", "output", @outfile, "dont_ask")
				@success = true
				return
			else
				if repaired || !UniJobsUtil::rc("pdftk", @children[0].outfile, "cat", "output", "../.tmp/tmp.pdf")
					@success = false
					return
				end
				repaired = true
			end
		end
	end
end
module JobIniter
	def title(x)
		return PDFTitleJob.new x
	end
end

class PDFShrinkJob < Job
	#@devel = rand(1000000)
	def initialize
		super()
	end
	def ggenout
		return ""
	end
	def rrun
		FileUtils.cp(@children[0].outfile, "../.tmp/tmp.pdf")
		if !UniJobsUtil::rc("pdfjam", "--nup", "2x4", "--outfile", "../.tmp/tmp2.pdf", "--no-landscape", "--frame", "true", "--delta", "0.5mm 0.5mm", "../.tmp/tmp.pdf")
			@success = false
		end
		if !UniJobsUtil::rc("pdfjam", "--trim", "-1.5cm -1.5cm -1.5cm -1.5cm", "--outfile", @outfile, "../.tmp/tmp2.pdf")
			@success = false
		end
	end
end

class PrintJob < Job
	def initialize(printid = nil)
		super()
		@printid = printid
	end
	def ggenout
		if @children[0].kind_of?(SaveJob)
			@printid ||= @children[0].realoutfile
			@children[0].printjobs.push self
		end
		return @printid
	end
	def rrun
		n = Notification.new("#{@printid} drucken?")
		n.choice("Ja") do
			if !UniJobsUtil::rc("lpr", "-o", "sides=two-sided-long-edge", @children[0].outfile)
				@success = false
			end
			FileUtils.touch @outfile
			true
		end
		n.choice("Nein") do
			FileUtils.touch @outfile
			puts "touch #{@outfile}"
			true
		end
	end
end
module JobIniter
	def pr
		return PrintJob.new
	end
end

class RepairGhostscriptJob < Job
	def initialize
		super()
	end
	def ggenout
		return ""
	end
	def rrun
		if !UniJobsUtil::rc("gs", "-sDEVICE=pdfwrite", "-sOutputFile=#{@outfile}", "-dNOPAUSE", "-dBATCH", @children[0].outfile)
			@success = false
		end
	end
end

class CompileTeXJob < Job
	def initialize()
		super()
	end
	def ggenout
		return ""
	end
	def rrun
		FileUtils.cp(@children[0].outfile, "../.tmp/tmp.tex")
		Dir.chdir("../.tmp/") do
			if !UniJobsUtil::rc("latexmk", "-pdf", "tmp.tex")
				@success = false
			end
		end
		if @success
			FileUtils.mv("../.tmp/tmp.pdf", @outfile)
		end
	end
end

class RemovePasswordJob < Job
	def initialize(pass)
		super()
		@password = pass
	end
	def ggenout
		return @password
	end
	def rrun
		FileUtils.cp(@children[0].outfile, "../.tmp/tmp.pdf")
		Dir.chdir("../.tmp/") do
			if !UniJobsUtil::rc("pdftops", "-upw", @password, "tmp.pdf") || !UniJobsUtil::rc("ps2pdf", "tmp.ps")
				@success = false
			end
		end
		if @success
			FileUtils.mv("../.tmp/tmp.pdf", @outfile)
		end
	end
end
module JobIniter
	def rmpass(pass)
		return RemovePasswordJob.new(pass)
	end
end

class SourceToPDFJob < Job
	def initialize(ext)
		@ext = ext
		super()
	end
	def ggenout
		return @ext
	end
	def rrun
		FileUtils.cp(@children[0].outfile, "../.tmp/tmp.#{@ext}")
		Dir.chdir("../.tmp/") do
			if !UniJobsUtil::rc("a2ps", "-B", "-E", "-R", "--columns=1", "-o", "../.tmp/tmp2.ps", "../.tmp/tmp.#{@ext}")
				@success = false
			elsif !UniJobsUtil::rc("ps2pdf", "-sPAPERSIZE=a4", "../.tmp/tmp2.ps", "../.tmp/tmp2.pdf")
				@success = false
			end
		end
		if @success
			FileUtils.mv("../.tmp/tmp2.pdf", @outfile)
		end
	end
end
