require 'icalendar'
require 'erb'
require 'slop'

opts = Slop.parse do |o|
  o.string '-m', '--me', 'email address of the owner of this calendar', required: true
  o.string '-s', '--start', 'start date of time period to analyse as YYYY/MM/DD', required: true
  o.string '-e', '--end', 'end date of time period to analyse as YYYY/MM/DD', required: true
  o.string '-o', '--out', 'output file (default: time.html)'
  o.on '--help', 'Show help' do
    puts 'Example usage'
    puts '  gcal-cruncher.rb --me davidsingleton@gmail.com --start 2018/1/1 --end 2018/3/31 cal.ics'
    exit
  end
end

me = opts[:me]
start_date = Date::strptime(opts[:start],"%Y/%m/%d")
end_date = Date::strptime(opts[:end],"%Y/%m/%d")
out_file = opts[:out]
if not out_file
  out_file = 'time.html'
end

range = start_date..end_date

in_count = 0
out_count = 0
time_with = {}
onetoone_with = {}

file_name = "cal.ics"
if !opts.arguments.empty?
  file_name = opts.arguments[0]
end

# Open a file or pass a string to the parser
cal_file = File.open(file_name)

# Parser returns an array of calendars because a single file
# can have multiple calendars.
cals = Icalendar::Calendar.parse(cal_file)
cals.first.events.each do |event|
  if range.include? event.dtstart.value.to_date then
    in_count += 1
    duration_mins = (event.dtend.value - event.dtstart.value) * 24 * 60

    if duration_mins > 12 * 60 or event.status != "CONFIRMED" then
      # ^ This is the best way I have found to filter all day events
      next
    end

    oo_ldap = nil
    attendee_count = 0

    event.attendee.each do |attendee|
      ldap = attendee.to_s.split('mailto:')[1]
      if !ldap.include?("calendar.google.com") and ldap != me
        time_with[ldap] = time_with[ldap].to_i + duration_mins
        attendee_count += 1
        oo_ldap = ldap
      end
    end

    if attendee_count == 1
      onetoone_with[oo_ldap] = onetoone_with[oo_ldap].to_i + duration_mins
    end
  else
    out_count += 1
  end
end


tw = time_with.sort_by{|k,v| v}.reverse
oow = onetoone_with.sort_by{|k,v| v}.reverse
max_tw = tw[0][1]
max_oow = oow[0][1]

template = File.read('./index.erb')
File.write(out_file, ERB.new(template).result(binding))

puts "Wrote #{out_file} events in range:#{in_count}"
