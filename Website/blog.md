# Manifest-Driven Markdown
**Date:** 2025-10-24  
**Tags:** markdown, automation
## The structure is as follows:

Started structuring the blog page to reflect my engineering mindset.  
Markdown parsing is next.

Use a blog.md file to document blog posts. Each post starts with metadata: date and tags. Posts are
separated by horizontal rules (---). Content can include headings, paragraphs, lists, and code
snippets. Node.js script will parse this file and generate HTML in a JSON for the blog page.
md-to-json.js will read blog.md, parse it, and output entry.json. blog-loader.js will read
entry.json and render the blog page.

More details to follow
### dan

---

# Synology Config Override
**Date:** 2025-10-25  
**Tags:** diagnostics, server
## The process is below:

Documented the robots.txt override fix for Synology. Planning to blog the diagnostic process.

The issue I was having was related to how my NAS builds the nginx config files.  
Okay let me back up a bit... I have a Synology DS720+ that hosts all of my stuff... media, backups,
files... this website, etc. I wanted to link my landing page to LinkedIn's Featured section. 

No biggie!

```Invoke-TrumpWrongGIF...```

LinkedIn was having none of it. After some digging, I discovered a page on the LinkedIn site that
would render how a post would look. This little tool was super helpful, and pointed me toward the
robots.txt file tied to my URL. The kicker was... no such file existed in the File Station
/volume1/web/.

At this point I SSH to my NAS, and I find 5 total files named robots.txt all living in nginx.conf.
So I sudo vi into the conf and inspect them. I modified them to say Allow / instead of Disallow
/, and restart nginx...

Alas, no change... Still disallow.

Now I'm starting to flex my Google-fu 3rd degree blackbelt combined with Copilot to see how this DSM
generates this nginx.conf.

After a few hours ... yes, hours ... of looking and digging around in the SSH, and with the help of
trusty Google and Copilot combo, I discover the nginx.conf is generated dynamically at service
startup, but there is one overriding little piece in a hidden usr dir.

DSM has a hidden user dir: ^/usr/syno^ that houses numerous automation and conf files.  
A quick grep for robots.txt in /usr/syno/ location revealed the culprit. A...

```sudo vi /usr/syno/share/nginx/optimization.mustache``` 

concealed a snippet that had this:

```location = /robots.txt { allow all; access_log off; log_not_found off; }```

After swapping that for this:

```location = /robots.txt { root /volume1/web; default_type text/plain; }```

(Which is my custom robots.txt file in the root web folder), BOOM! Disallow / became Allow / and
loading into LinkedIn was possible...after restarting nginx again of course.

So hopefully this helps someone out there,
### dan

---

# Automating Blog Generation
**Date:** 2025-10-25 
**Tags:** automation, blogging
## The workflow is as follows:

Started automating blog generation using Node.js scripts to parse markdown and generate HTML. The
plan is to create a seamless workflow for adding new blog posts.

1. Write blog posts in blog.md using markdown syntax.
2. Run md-to-json.js to parse blog.md and generate entries.json.
3. Use blog-loader.js to read entry.json and render the blog page
4. Created Scheduled Task using Synology DSM to automate running md-to-json.js every 15 minutes.
5. Which deploys the updated blog page to the website.

All the code is on my GitHub if anyone wants to check it out. I'm currently working on the
watch-blog.js to monitor changes in real-time.

I love being nerdy like this!
### dan

---

# Building This Website
**Date:** 2025-10-26 
**Tags:** coding, server, networking
## Below are some thoughts on the process:

Started with an idea to have a centralized resume to eliminate juggling dozens of file versions.
Easier this way to manage formatting and versioning.

I had to figure out how to get the server alias portal setup in DSM ... Synology's DSM is pretty
unique. I didn't want it to interfere with the DSM interface and site, so the alias of /dan/ was a
good compromise. 

The site files are all housed in that dir. /volume1/web is the default webserver dir, so the alias
lived in my folder /dan.

/volume1/web/dan/

Setting up the alias web portal under the Web Service tab in Web Station was pretty straight
forward. Create a static site with your alias and point it at whatever dir you decide on. After
that, just make sure your folder allows http user read access to the folder.

Obviously, you'll need to port forward 80 and 443 to your webserver. I ended up setting up a Reverse
Proxy in DSM to handle all 80 and 443 requests and route them to internal apps. Firewall hardening
on the webserver is highly recommended as well. I will be making a post about that in the coming
days.

## Coding the site:

It started with just resume.html...just laying down the framework for the styling to come next. I
brainstormed a 'north star' sort of theme that I wanted the entire site to follow. I settled on my
favorite movie trilogy (if the theme isn't obvious at this point then you've been living under a
rock lol). THE MATRIX. Then, I created the central matrix-theme.css and built on top of that with
the little JavaScript file to handle the matrix-rain.js effect in the background on my entire site.
Google and Copilot came in handy to find all, or most, of the characters used in the film.

Coding this blog was probably my favorite nerd hack. I automated the process (and documented it in a
previous post) where all I need to do is update the blog.md file and save to the server. The
automated task runs my md-to-json.js script to parse it into a json that is easily digestable by
HTML. 

My next favorite was making a print-resume.css and a new button on the resume.html that renders a
very recruiter friendly version. Clicking the Download PDF button opens a browser print window with
the specialized recruiter friendly version.

From the style of Baudrillard, the link in the upper right corner was my tip of the cap. In one of
the first chapters of the first film, Neo has his programs hidden in a book by Baudrillard.

```Welcome to the desert of the real...```

I tought the connection between that book by Baudrillard and the film trilogy is uncanny.

Anyway, all in all, this has been a super fun project to work on that took a lot of planning, and
research. Trial and error. Not to mention some late nights coding and debugging. Totally worth it!

All my code is posted on my GitHub! Please feel as free as Zion after Smith's destruction to reach
out!
### dan

---

# Securing Synology DSM
**Date:** 2025-10-26 
**Tags:** security, server, firewall
## Documented my Synology DSM hardening process to enhance security.

Started with basic firewall rules, then moved to advanced settings.

### The steps taken are as follows:

1. Enabled Synology's built-in firewall and created and made a rule set to deny all incoming traffic
   by default and keep it at the bottom of the rule list.

2. Created allow rules for only necessary services (e.g., SSH, HTTPS, HTTP) from specific IP
   addresses or ranges; change from default SSH port to something obscure.

3. Created GeoIP blocking rules to deny traffic from high-risk countries. Put this one at the top of
   the rule list.

4. Disabled unused services to minimize attack surface.

5. Enabled 2FA for all user accounts to add an extra layer of security.

6. Disabled default admin account and created a new admin user with a strong password.

7. Regularly updated DSM and installed packages to ensure all security patches

More to come soon on details of each step.
### dan

---

# Creating w32time Config Scripts
**Date:** 2025-10-27 
**Tags:** scripting, server, client
## Why is this workstation's time two minutes off?

NTP server issues most likely

## Fix it like this:

Start by checking what, if any, NTP servers are working on the network. If it's a domain network,
that makes it even easier. The PDC should (emphasis on should) be doing the work letting the
workstations know this tiny, but very important, piece of information. NTP uses UDP port 123 by
default for communication, so make sure devices are listening to (and have the firewall not block)
port 123.

## Server config commands:

```
w32tm /config /manualpeerlist:"time.windows.com,0x1" /syncfromflags:manual /reliable:YES /update

Restart-Service w32time

Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\NtpServer" -Name "Enabled" -Value 1

Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Config" -Name "AnnounceFlags" -Value 5

New-NetFirewallRule -DisplayName "Allow NTP Server (UDP 123)" -Direction Inbound -Protocol UDP -LocalPort 123 -Action Allow

$action = New-ScheduledTaskAction -Execute "C:\Windows\System32\w32tm.exe" -Argument "/resync"

$trigger = New-ScheduledTaskTrigger -Daily -At 12:00PM

Register-ScheduledTask -TaskName "DailyNTPServerResync" -Action $action -Trigger $trigger -User "SYSTEM" -RunLevel Highest -Force 
```

The clients should be listening to the PDC by default when they are joined to the domain. As long as
the domain controller is configured properly, the clients should fall in line. See below for client
config commands (run on workstation).

## Client config commands:

```
w32tm /config /syncfromflags:all /manualpeerlist:"time.windows.com,0x1" /reliable:YES /update

Restart-Service w32time

$action = New-ScheduledTaskAction -Execute "C:\Windows\System32\w32tm.exe" -Argument "/resync"

$trigger = New-ScheduledTaskTrigger -Daily -At 12:00PM

Register-ScheduledTask -TaskName "DailyTimeResync" -Action $action -Trigger $trigger -User "SYSTEM" -RunLevel Highest -Force 
```

Protip: Paste the code block into PowerShell IDE and press play, or make it a script to run from an
elevated PS console.
### dan

---

# Creating my Workstation Deployment software suite
**Date:** 2025-10-28
**Tags:** coding, setup, automation
## This one was born almost out of necessity

I am always looking to develop very indepth knowledge of PowerShell and gain a deeper understanding
of Windows itself. My idea was to try and make the SOP for the company I worked for off of a piece 
of paper and into a script. Manually doing every step on a PC was not only tedious, it was very 
errorprone, which was causing a bit of blowback when I missed a step here and there. The 
post-projects team audited each workstation, so we'd here about it if we were missing stuff. 

### ENTER THE POWERSHELL SCRIPT!!

I just knew there had to be a way to make a reliable automated system for each workstation to run
through in the order on the SOP, never missing a step. It was a huge undertaking, and therefore a 
huge challenge, but I was more than up for it. (This was a personal project and goal for me by 
the way). I was just starting to get my feet back under me after a health problem caused some s
cognitive decline until it was "cured" (I can dive into that later, but it's personal...This 
blog is more of a technical blog, and less of a personal nature). Anyway let's dive into the
WS_Setup_6 project instead!

## To be continued...

---

# Workstation Deployment Software suite (cont.)
**Date:** 2025-10-28
**Tags:** coding, setup, automation
## Continuing with the story

So I needed to start small. Every journey starts with step one. My step one in this case was to
forget about any UI integrations and just focus on commands in PowerShell to automate what I was
clicking on 743,879 times per project, per workstation. The first command was pretty simple:

```
$UACRegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
$UACValueName = "EnableLUA"
Set-ItemProperty -Path $UACRegistryPath -Name $UACValueName -Value 0 -Type DWord 
```

Not the most secure option here, I know, but at the time we were working with a client that had
practice management software that required UAC to be disabled entirely, or parts of it would have
fatal errors at runtime. Basically, this disabled it entirely...

From there it showballed into several other pieces of a PS script that I affectionately named
"Onboarding.ps1" This was the catalyst for a 10 month long journey from one single PS command to a
full blown onboarding tool complete with MahApps UI and C# backend with a WiX installation toolset
for a polished and professional look at install time.

## To be continued...