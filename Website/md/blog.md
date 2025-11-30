# Shoutout to freeCodeCamp!

**Date:** 2025-10-22 **Tags:** coding, learning, coursework

## This site was how I got my toes damp.

I would highly recommend freeCodeCamp if you're wanting to get into any level of
web coding. It was SUPER helpful for me getting my tooties damp...well...almost
2 years ago now at this point.

[Here is a link](https://www.freecodecamp.org/)

Highly recommend it!!

### dan

---

# Manifest-Driven Markdown

**Date:** 2025-10-24 **Tags:** markdown, automation

## The structure is as follows:

Started structuring the blog page to reflect my engineering mindset.  
Markdown parsing is next.

Use a blog.md file to document blog posts. Each post starts with metadata: date
and tags. Posts are separated by horizontal rules (---). Content can include
headings, paragraphs, lists, and code snippets. Node.js script will parse this
file and generate HTML in a JSON for the blog page. md-to-json.js will read
blog.md, parse it, and output entries.json. blog-loader.js will read
entries.json and render the blog page.

More details to follow

### dan

---

# Synology Config Override

**Date:** 2025-10-25 **Tags:** diagnostics, server

## The process is below:

Documented the robots.txt override fix for Synology. Planning to blog the
diagnostic process.

The issue I was having was related to how my NAS builds the nginx config files.
Okay let me back up a bit... I have a Synology DS720+ that hosts all of my
stuff... media, backups, files... this website, etc. I wanted to link my landing
page to LinkedIn's Featured section.

No biggie!

`Invoke-TrumpWrongGIF...`

LinkedIn was having none of it. After some digging, I discovered a page on the
LinkedIn site that would render how a post would look. This little tool was
super helpful, and pointed me toward the robots.txt file tied to my URL. The
kicker was... no such file existed in the File Station /volume1/web/.

At this point I SSH to my NAS, and I find 5 total files named robots.txt all
living in nginx.conf. So I sudo vi into the conf and inspect them. I modified
them to say Allow / instead of Disallow /, and restart nginx...

Alas, no change... Still disallow.

Now I'm starting to flex my Google-fu 3rd degree blackbelt combined with Copilot
to see how this DSM generates this nginx.conf.

After a few hours ... yes, hours ... of looking and digging around in the SSH,
and with the help of trusty Google and Copilot combo, I discover the nginx.conf
is generated dynamically at service startup, but there is one overriding little
piece in a hidden usr dir.

DSM has a hidden user dir: /usr/syno that houses numerous automation and conf
files.  
A quick grep for robots.txt in /usr/syno/ location revealed the culprit. A...

`sudo vi /usr/syno/share/nginx/optimization.mustache`

concealed a snippet that had this:

`location = /robots.txt { allow all; access_log off; log_not_found off; }`

After swapping that for this:

`location = /robots.txt { root /volume1/web; default_type text/plain; }`

(Which is my custom robots.txt file in the root web folder), BOOM! Disallow /
became Allow / and loading into LinkedIn was possible...after restarting nginx
again of course.

So hopefully this helps someone out there,

### dan

---

# Automating Blog Generation

**Date:** 2025-10-25 **Tags:** automation, blogging

## The workflow is as follows:

Started automating blog generation using Node.js scripts to parse markdown and
generate HTML. The plan is to create a seamless workflow for adding new blog
posts.

1. Write blog posts in blog.md using markdown syntax.
2. Run md-to-json.js to parse blog.md and generate entries.json.
3. Use blog-loader.js to read entry.json and render the blog page
4. Created Scheduled Task using Synology DSM to automate running md-to-json.js
   every 15 minutes.
5. Which deploys the updated blog page to the website.

All the code is on my GitHub if anyone wants to check it out. I'm currently
working on the watch-blog.js to monitor changes in real-time.

I love being nerdy like this!

### dan

---

# Building This Website

**Date:** 2025-10-26 **Tags:** coding, server, networking

## Below are some thoughts on the process:

Started with an idea to have a centralized resume to eliminate juggling dozens
of file versions. Easier this way to manage formatting and versioning.

I had to figure out how to get the server alias portal setup in DSM ...
Synology's DSM is pretty unique. I didn't want it to interfere with the DSM
interface and site, so the alias of /dan/ was a good compromise.

The site files are all housed in that dir. /volume1/web is the default webserver
dir, so the alias lived in my folder /dan.

/volume1/web/dan/

Setting up the alias web portal under the Web Service tab in Web Station was
pretty straight forward. Create a static site with your alias and point it at
whatever dir you decide on. After that, just make sure your folder allows http
user read access to the folder.

Obviously, you'll need to port forward 80 and 443 to your webserver. I ended up
setting up a Reverse Proxy in DSM to handle all 80 and 443 requests and route
them to internal apps. Firewall hardening on the webserver is highly recommended
as well. I will be making a post about that in the coming days.

## Coding the site:

It started with just resume.html...just laying down the framework for the
styling to come next. I brainstormed a 'north star' sort of theme that I wanted
the entire site to follow. I settled on my favorite movie trilogy (if the theme
isn't obvious at this point then you've been living under a rock lol). THE
MATRIX. Then, I created the central matrix-theme.css and built on top of that
with the little JavaScript file to handle the matrix-rain.js effect in the
background on my entire site. Google and Copilot came in handy to find all, or
most, of the characters used in the film.

Coding this blog was probably my favorite nerd hack. I automated the process
(and documented it in a previous post) where all I need to do is update the
blog.md file and save to the server. The automated task runs my md-to-json.js
script to parse it into a json that is easily digestable by HTML.

My next favorite was making a print-resume.css and a new button on the
resume.html that renders a very recruiter friendly version. Clicking the
Download PDF button opens a browser print window with the specialized recruiter
friendly version.

From the style of Baudrillard, the link in the upper right corner was my tip of
the cap. In one of the first chapters of the first film, Neo has his programs
hidden in a book by Baudrillard.

`Welcome to the desert of the real...`

I tought the connection between that book by Baudrillard and the film trilogy is
uncanny.

Anyway, all in all, this has been a super fun project to work on that took a lot
of planning, and research. Trial and error. Not to mention some late nights
coding and debugging. Totally worth it!

All my code is posted on my GitHub! Please feel as free as Zion after Smith's
destruction to reach out!

[GitHub Website Code repo](https://github.com/dan-damit/Scripts-and-Snippets/tree/main/Website)

### dan

---

# Securing Synology DSM

**Date:** 2025-10-26 **Tags:** security, server, firewall

## Documented my Synology DSM hardening process to enhance security.

Started with basic firewall rules, then moved to advanced settings.

### The steps taken are as follows:

1. Enabled Synology's built-in firewall and created a rule set to deny all
   incoming traffic by default and keep it at the bottom of the rule list.

2. Created allow rules for only necessary services (e.g., SSH, HTTPS, HTTP) from
   specific IP addresses or ranges; change from default SSH port to something
   obscure.

3. Created GeoIP blocking rules to deny traffic from high-risk countries. Put
   this one at the top of the rule list.

4. Disabled unused services to minimize attack surface.

5. Enabled 2FA for all user accounts to add an extra layer of security.

6. Disabled default admin account and created a new admin user with a strong
   password.

7. Regularly updated DSM and installed packages to ensure all security patches

More to come soon on details of each step.

### dan

---

# Creating w32time Config Scripts

**Date:** 2025-10-27 **Tags:** scripting, server, client

## Why is this workstation's time two minutes off?

NTP server issues most likely

## Fix it like this:

Start by checking what, if any, NTP servers are working on the network. If it's
a domain network, that makes it even easier. The PDC should (emphasis on should)
be doing the work letting the workstations know this tiny, but very important,
piece of information. NTP uses UDP port 123 by default for communication, so
make sure devices are listening to (and have the firewall not block) port 123.

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

The clients should be listening to the PDC by default when they are joined to
the domain. As long as the domain controller is configured properly, the clients
should fall in line. See below for client config commands (run on workstation).

## Client config commands:

```
w32tm /config /syncfromflags:all /manualpeerlist:"time.windows.com,0x1" /reliable:YES /update

Restart-Service w32time

$action = New-ScheduledTaskAction -Execute "C:\Windows\System32\w32tm.exe" -Argument "/resync"

$trigger = New-ScheduledTaskTrigger -Daily -At 12:00PM

Register-ScheduledTask -TaskName "DailyTimeResync" -Action $action -Trigger $trigger -User "SYSTEM" -RunLevel Highest -Force
```

Protip: Paste the code block into PowerShell IDE and press play, or make it a
script to run from an elevated PS console.

### dan

---

# Creating my Workstation Deployment software suite

**Date:** 2025-10-28 **Tags:** coding, setup, automation

## This one was born almost out of necessity

I am always looking to develop very indepth knowledge of PowerShell and gain a
deeper understanding of Windows itself. My idea was to try and make the SOP for
the company I worked for off of a piece of paper and into a script. Manually
doing every step on a PC was not only tedious, it was very errorprone, which was
causing a bit of blowback when I missed a step here and there. The post-projects
team audited each workstation, so we'd here about it if we were missing stuff.

### ENTER THE POWERSHELL SCRIPT!!

I just knew there had to be a way to make a reliable automated system for each
workstation to run through in the order on the SOP, never missing a step. It was
a huge undertaking, and therefore a huge challenge, but I was more than up for
it. (This was a personal project and goal for me by the way). I was just
starting to get my feet back under me after a health problem caused some s
cognitive decline until it was "cured" (I can dive into that later, but it's
personal...This blog is more of a technical blog, and less of a personal
nature). Anyway let's dive into the WS_Setup_6 project instead!

## To be continued...

---

# Workstation Deployment Software suite (cont.)

**Date:** 2025-10-28 **Tags:** coding, setup, automation

## Continuing with the story

So I needed to start small. Every journey starts with step one. My step one in
this case was to forget about any UI integrations and just focus on commands in
PowerShell to automate what I was clicking on 743,879 times per project, per
workstation. The first command was pretty simple:

```
$UACRegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
$UACValueName = "EnableLUA"
Set-ItemProperty -Path $UACRegistryPath -Name $UACValueName -Value 0 -Type DWord
```

Not the most secure option here, I know, but at the time we were working with a
client that had practice management software that required UAC to be disabled
entirely, or parts of it would have fatal errors at runtime. Basically, this
disabled it entirely...

From there it showballed into several other pieces of a PS script that I
affectionately named "Onboarding.ps1" This was the catalyst for a 10 month long
journey from one single PS command to a full blown onboarding tool complete with
MahApps UI, C# backend, and a WiX installation toolset, for a polished and
professional look at install time.

## To be continued...

---

# Tweaking the layout

**Date:** 2025-10-29 **Tags:** coding, css

## I wanted to make it look even better

I wanted to make the site look better, so I went back to school for a bit
reading about concepts for website layouts, and how to hook them up. And so far
I think it's been looking way better! The first piece that I wanted to adjust
were the two buttons at the top. They needed to go above the main content div
and not be transparent. That way they looked like they were floating above it
all. Kind of like a 3d effect. I also added a hover::after piece to the link for
some additional info for the clicker. I'm still trying to build it in a way
where it can adapt to any screen resolution...

Next was a footer. And it took a bit of reading that a good practice is to wrap
the whole thing in a div that ends with the footer. And in there I added a sort
of nav menu. I also wanted to reduce the amount of glyphs that rained by 1/2. It
was just too busy, and I think cutting it in half works perfectly.

After that I cobbled together a bash script to grab hardware diag data from my
server, output it to a json, and scheduled it to run every 5 minutes. With the
help of a short JavaScript file, the data in the json gets outputted to the
index.html as the status div.

I think it's coming together nicely. Just gotta keep on tinkering!

### dan

---

# The System Diagnostics home page workflow

**Date:** 2025-10-30 **Tags:** automation, scripting

## Automating the sysdiag workflow for the home page

I wanted to add more to the home page. What better to fit the theme than a
system diagnostics widget?? I think it adds an additional cool factor to see
real time stats of my server.

I started with a shell script (Synology runs a sort of custom flavor of debian)
to grab all the server's hardware info, staring with Hostname and ending with
Last Sync entries. I setup a task in the Task Scheduler like the other
md-to-json.js script to run the generate-manifest.sh script. This script grabs
the info, and outputs it to a manifest.json file. Then, I have a small js file
that grabs the info in the json to pop it on the home scree.

### dan

---

# Refactoring the CSS and JS code

**Date:** 2025-10-31 **Tags:** coding, css, javascript

## The idea was to stay with my preferred modular code style

I wanted to say in line with my preferred design philosophy about keeping things
as modular as possible for clarity, maintainability, and "separation of
concerns" in the structure of the site; just like I prefer in other
coding/scripting areas like PowerShell. Modularity is one of my core prinicples
when it comes to ...well... anything in my life, not just coding.

[Check out the new structure here](https://github.com/dan-damit/Scripts-and-Snippets/tree/main/Website)

The more I added, the longer and longer the matrix-theme.css became, and it was
on its way to 1000 lines with the rate I was going. Breaking that out into 7
separate css files and restructuring the site folders only made sense. It was
going to be easier to refactor stuff now versus a few months from now when I
have a dozen pages and not just the four currently.

Now I wonder how long it is until my blog gets so large that it takes forever to
load on someone's browser window... then what? break it up into multiple pages
with like 10 or 15 per page?

Something to think about for sure...

### dan

---

# Updating the matrix-rain.js behavior

**Date:** 2025-11-2 **Tags:** coding, javascript, css

## I found a nifty upgrade to the matrix rain canvas online

Surfing the web. My favorite passtime. I stumbled across an articke on
medium.com about the matrix rain effect on a canvas element that added what I
think is a cool effect on the characters "raining" in the background. They
achieved it using a method that had not occured to me. Layering with multiple
canvas elements, but also adding a blurring affect to the chacters that fade to
clear then back to blurry after a short time passes. It's brilliant.

I want to make the Matrix rain canvas as close to one of the final chapers in
the first film. When Neo decides he doesn't want to die after the encounter with
Smith. He gets up in the ratty hallway of the apartment building, and you get
your first glimpse of what Neo sees. That rain affect is on every surface; the
walls, the floor, the ceiling....the agents. The 4 layers deep work together to
get really close to that effect on the canvas backdrop on the site.

[Code here](https://github.com/dan-damit/Scripts-and-Snippets/blob/main/Website/js/matrix-rain.js)

I modified it a little bit to better fit on some of my pages that have a decent
vertical scroll.

```
canvas { height: 100% }

canvas.height = Math.max(document.body.scrollHeight, document.documentElement.scrollHeight);
```

The CSS and JS combo above slowed it down on the taller total px number on the
resume.html page

### dan

---

# Constant improvement

**Date:** 2025-11-3 **Tags:** javascript, coding

## I broke my matrix-rain.js trying to introduce scaling font size

I was trying to slow down the animation and make the glyphs larger based on the
current window resolution. It started well, but ended up getting to the point
where each glyph was getting drawn like 12 times in one square. So, as the
number of frames increased, it would blog down the browser performance
exponentially. It was honestly kind of funny...

```
matrixRain("matrixCanvas3", { speedFactor: 0.8, fontSize: 12, delayFactor: 4 });
```

Adding to the delayFactor slowed the downward movement of the glyphs, but they
still were drawing at the same speed. Need some more thinking on this to see if
a combination of speedFactor and delayFactor can slow down the draw speed and
downward movement in a way that doesn't completely crash the browser. But it all
has a different affect depending on the innerWidth and innerHeight...

```
for (let i = 0; i < drops.length; i++) {
   const text = characters[Math.floor(Math.random() * characters.length)];
   const x = i * fontSize;
   const y = drops[i] * fontSize;

   ctx.fillText(text, x, y);

   // Move the drop down based on delay
   if (delays[i] <= 0) {
       drops[i] += 1; // Move down one step
       delays[i] = Math.random() * (delayFactor / speedFactor); // Reset delay with layer-specific delayFactor
   } else {
       delays[i] -= 1; // Reduce delay
   }

   // Reset drop to the top randomly
   if (y > canvas.height && Math.random() > 0.975) {
       drops[i] = 0; // Reset to the top
   }
}
```

Anyway, I had to go back to several revisions earlier in the matrix-rain.js
because...well if the browser crashes after trying to run the script longer than
15 seconds... not cool.

[Code here](https://github.com/dan-damit/Scripts-and-Snippets/blob/main/Website/js/matrix-rain.js)

Anyway, I think as this blog grows, I think I'll add a sort of tag list to the
right side of the blog-container with like 25px of margin, but keeping the
blog-container centered.

### dan

---

# Waaaay too many glyphs

**Date:** 2025-11-4 **Tags:** javascript, coding

## The 4 layered approach crushed slower PCs

The title says it all for this one. Having 4 canvases caused slower CPU/CPU
combos to lag out horribly. So I adjusted it back to 1 layer. The updated code
loop is below:

```
const canvases = document.querySelectorAll('#matrixCanvasMain');
```

One main canvas instead of 4.

Now it looks as good but not super blurry at times on 2 of the 4 layers. I also
tried to randomize glyph size and speed too

[Code here](https://github.com/dan-damit/Scripts-and-Snippets/blob/main/Website/js/matrix-rain.js)

### dan

---

# Creating a new page

**Date:** 2025-11-5 **Tags:** html, css, coding

## I added a "current projects" page

Complete with links to their GitHub pages. I wanted to add another page and this
seemed like a good next step to sort of showcase what I'm currently working on.
I love to tinker... It was a great opportunity to learn about "cards" in html.
Each project gets a "card"

[Code here](https://github.com/dan-damit/Scripts-and-Snippets/blob/main/Website/projects.html)

Next up, I think I'm going to add that floating side menu on the blog page that
will list all of the tags currently indexed.

### dan

---

# Adding the All Tags pane

**Date:** 2025-11-7 **Tags:** html, css, javascript

## Took a lot of restructuring

Just to get a little pane on the right that shows the list of all parsed tags
was a little tougher than I originally anticipated. I didn't want to mess too
much with the blog-loader.js only needed to add a foreach loop to grab all the
tags and output them to a list. Getting the layout right was the tricky part. It
took, other than the forEach loop in the blog-loader.js, a restructure of the
html in the blog.html file with an additional flexbot wrapper.

I also made it so the all tags list display:none for small resolutions like
mobile browsers. It just looked cleaner that way.

```
allTags.forEach(tag => {
    const tagBtn = document.createElement('button');
    tagBtn.className = 'tag-index-button';
    tagBtn.textContent = tag;
    tagBtn.type = 'button';
    tagBtn.addEventListener('click', () => {
        const filtered = allEntries.filter(entry => entry.tags.includes(tag));
        renderPage(filtered, 1, tag);
        console.log(`[TagIndex] ${tag} → ${filtered.length} entries`);
    });
    tagIndex.appendChild(tagBtn);
});
```

[Code here](https://github.com/dan-damit/Scripts-and-Snippets/tree/main/Website)

### dan

---

# Home networking improvements

**Date:** 2025-11-8 **Tags:** networking, firewall

## GeoIP Firewalling and IoT VLANing

I wanted to harden up my network since several ports are open directly to my
server. Mikrotik doesn't have a fancy checkbox for geoip blocking. I had to
leverage the Mikrotik Wiki with a lot of reading to wrap the brain stem around
how to block high risk countries. Mikrotik has IP lists that they reqularly
update with the IP blocks for these country. I created a short script to
download these from Mikrotik and apply them in my top firewall rule. That rule
combined with a all, all, deny type of rule at the very bottom meant nothing
would be getting through unless I explicitly made a rule or a NAT for it. Which
is what I did next.

Ports 25,80,443,587,465 are all I ended up opening on the edge firewall - the
hEX S. Next up was the firewall on the server. I opened these ports along with
some others that were required for DSM and other Synology apps to function
correctly. I applied the same firewalling logic to the server's firewall as
well. Geoip blocking at the top; all, all, deny at the bottom. Only opened the
necessary port in between them.

```
/tool/fetch url="https://mikrotik-geoip.com/free/?version=7&family=ipv4&type=firewall&country=CN" output=file dst-path=MikroTik-GeoIP-CN.rsc
/import file-name=MikroTik-GeoIP-CN.rsc
```

I used the above commands to retrieve China's IP blocks, along with several
other high risk countries like Russia and Irag/Iran. All that was needed was
changing the country code in the command and it grabbed that country's IP blocks
into the .rsc file.

```
/ip firewall filter add chain=input src-address-list=CN action=drop comment="GeoIP Block - China"
```

Then created rules based on the coutnry code in the files. I also looked into
keeping these .rsc files current

```
/system scheduler add name="UpdateGeoIP_CN" interval=1d on-event="/tool/fetch url=\"https://mikrotik-geoip.com/free/?version=7&family=ipv4&type=firewall&country=CN\" output=file dst-path=GeoIP-CN.rsc; /import file-name=GeoIP-CN.rsc"
```

I did this for roughly 12 countries in total that are considered "high risk"

## IoT VLANing

So I wanted to segment the network into the IoT stuff that likes to phone home
often like Roku devices, and the secure devices like my server and Desktop Rig.
I already had the SSIDs and their separate security in place, so it was just a
matter of getting the rest of the config correct under the hood. I even already
had the VLAN sub interface attached to the bridge correctly. All I needed to do
to finish up the config was attach a DCHP scope to the VLAN interface and create
the firewall rules to limit cross-vlan traffic. The only things that the IoT
devices can talk to is Plex server and Pihole for DNS filtering. Everything is
allowed the other direction, however.

Network security is on point now.

### dan

---

# Changing the styling of the blog

**Date:** 2025-11-9 **Tags:** css, javascript

## I love the cards look

I love the way the projects page turned out with the use of cards, so I wanted
to adapt that and apply it to the blog. I think it turned out awesome, and I
reworked the font-family to be the same across the blog page. All it took was a
little change to the renderPage function and a few small additions to the
blog.css. I went through the blog.css as well and paired it down a bit. I
noticed that I had several duplicate classes.

```
pageEntries.forEach((entry) => {
    const card = document.createElement("div");
    card.className = "blog-card";
    card.setAttribute("data-tags", entry.tags.join(","));

    card.innerHTML = `
      <h2 class="blog-title">${entry.date}: ${entry.title}</h2>
      <div class="tags">
        ${entry.tags.map((tag) => `<span class="tag">${tag}</span>`).join(" ")}
      </div>
      <div class="content" style="display:none;">${entry.content}</div>
      <button type="button" class="toggle">Decrypt</button>
    `;

    container.appendChild(card);
  });
```

Also I wanted to make the hover effect really zoom in on the entry.

```
.blog-card {
  background-color: transparent;
  border: 2px solid var(--neon-green);
  border-radius: 6px;
  padding: 1em;
  margin: 1em 0;
  font-family: "Courier New", Courier, monospace;
  box-shadow: 0 0 10px var(--neon-green);
  transition: transform 0.25s ease-in-out;
  z-index: 20;
}

.blog-card:hover {
  transform: scale(1.25);
  background-color: black;
  box-shadow: 0 0 25px var(--soft-green);
  z-index: 25;
}
```

The effect is pretty awesome when you hover over the card now!

[Code here](https://github.com/dan-damit/Scripts-and-Snippets/blob/main/Website/js/blog-loader.js)

### dan

---

# IoT and WiFi

**Date:** 2025-11-10 **Tags:** networking, wifi, ssid

## So this one was interesting

Got dispatched to fix some security cammera connectivity issues from a vendor
that were using WiFi (ewwwww). We swapped the Firewall from SonicWall to UDM
Pro, moved the configs from the old UniFi controller to the UDM, and called it a
day.

Fast forward 2 months.

We get a call from their security vendor saying their cameras have been offline
since the swap. Our support team did all they could think of remotely, but the
cameras just couldn't see the SSID, which is MFD - Internal. The SSID is
attached to the default VLAN, and it's just a small office kind of network.
Small and easy to manage.

## Troubleshooting

My first idea was to create a new SSID just for the security cameras. MFD -
Security is the SSID. The camera we were testing on could see it no problem.
That told me there was something wrong with the SSID itself or how it was being
broadcast. My first thought from there was it's 2.4G only. Okay cool, so I
turned off 5GHz broadcasting for the Internal SSID, no change. Still cannot see
the SSID. Okay, so I ran through all the settings for the Internal SSID. Nothing
really stood out as off or as something that would interefere with the cameras
themselves not see the SSID.

## Then I noticed it...

The dash in the SSID didn't look right. Sure enough, it must have been of a
different character set than what you usually see on a normal US keyboard. I
deleted the existing "-" character and added the new "-" from my keyboard,
rescanned the SSIDs from the camera interface, and BAM! SSID is there. Not only
did the one we were testing with see the SSID now, but the other 3 cameras
connected up on their own once I cliced "save" with the correct dash character
in the SSID.

That was a fun one!

### dan

---

# Created a custom $PROFILE

**Date:** 2025-11-11 **Tags:** powershell, scripting

## Went with a custom Matrix theme (of course)

I was doing some reading on how powershell handles the $PROFILE and learned that
you can do custom profiles! How awesome! I followed that white rabbit for hours!

```
$PROFILE
```

That simple variable entry into the prompt reveals the path of the profile.ps1.
I went full custom mode and added glyphs and a function that simulates
decrypting data in the console, and finishes with a custom lambda character for
the prompt.

There is another script that I have been working on as well in a later post.
It's a custom PowerShell subnet scanner.

[Custom Profile Code here](https://github.com/dan-damit/Scripts-and-Snippets/blob/main/PowerShell/Microsoft.PowerShell_profile.ps1)

I took it a step further and adapted this to a little exe to run anywhere
anytime that does the same thing, but with Windows PowerShell 5.1. My favorite
feature of the portable custome shell exe is that the prompt defaults to
whatever directory from which it's ran.

[Custom Portable Shell Launcher](https://github.com/dan-damit/Scripts-and-Snippets/blob/main/PowerShell/Launch-CustomShell.ps1)

Compiled that to an exe with PS2EXE module for a super lightweight and portable
custom one-time PowerShell profile.

### dan

---

# My custom PowerShell IP Scanner

**Date:** 2025-11-13 **Tags:** networking, scripting

## I wanted something custom and concise

I wanted a custom scanner that not only records pings to determine if something
is online at that address, I also wanted it to grab two important datapoints:

1. A hostname
2. If port 80 was open (usually an indicator of a webserver on board)

The hostname bit...I read up on it for a while to see what reliable way to find
the hostname, and I settled on using PTR record to log hostname. Time will tell
if this is the best, most reliable way... For the port 80, it also looks for
https headers as well, so if it scans and sees a printer for example, usually
those have some sort of webserver that serves up an interface to interact with
for config, etc.

[Code here](https://github.com/dan-damit/Scripts-and-Snippets/blob/main/PowerShell/PowerShell.IP.Scan.ps1)

I even signed it so it might not get tripped up running it remotely. Which
brings me to my next post in the coming couple of days. I made a custom code
signing script that I compiled into an exe with the cert embedded as base64
encoded.

### dan

---

# Testing out the scanner in the wild

**Date:** 2025-11-14 **Tags:** networking, scripting

## Adding more info

I noticed after using it in testing, that IP and PTR wasn't quite enough. I
ended up adding a MAC address column, and a couple different ways to grab
hostname like mDNS and NetBIOS.

The MAC was probably the most notable improvement.

[Code here](https://github.com/dan-damit/Scripts-and-Snippets/blob/main/PowerShell/PowerShell.IP.Scan.ps1)

### dan

---

# Created a basic UI using Windows.Forms

**Date:** 2025-11-17 **Tags:** scripting, gui, powershell

## A reusable UI script to apply to interactive scripts

I realize I wanted to start wrapping my scripts in a GUI and compile it to EXE
with PS2EXE module. I think that would be an awesome touch for very frequently
used scripts. I ended up creating a Basic UI layout with Windows.Forms in a
PowerShell file.

[Code here](https://github.com/dan-damit/Scripts-and-Snippets/blob/main/UI/Basic_UI.ps1)

I applied it to several scripts over the weekend and the result is spactacular.
Now I wonder if I can get an ico library for compiling them with PS2EXE

### dan

---

# Adjusting the blog structure

**Date:** 2025-11-19 **Tags:** javascript, scalability

## Was forseeing some scalability issues

I thought that I was going to end up running into scalability issues with the
blog as it continues to grow. I thought it would be best then to slightly
restructure the md-to-json.js to look for multiple blog markdown files. This way
it's not only safer so I won't lose everything in the worst case scenario, it
will be easier to break up the one huge blog.md file into multiple. I'm thinking
by month.

I created a new folder /md and moved the blog.md file to this folder, and will
make a new blog.md file month to month. blog1.md , blog2.md , etc. Then the
script will grab and parse each file in the /md dir.

[Code here](https://github.com/dan-damit/Scripts-and-Snippets/blob/main/Website/md-to-json.js)

I also had to adjust the blog-loader just slightly as well, but that was only a
couple lines.

---

# Creating a simple robocopy script

**Date:** 2025-11-24 **Tags:** powershell, scripting

## Had a fun task that presented the opportunity

I had a service call today to combine two shared folders into one after the
retirement of a management person. They wanted to take the retiree folder and
the newly promoted manager share folders and combine them into one just simply
called Management. There was quite a bit between the two folders, so I saw that
as an opportunity to create a simple robocopy PowerShell script to accomplish
the task safely.

[Code here](https://github.com/dan-damit/Scripts-and-Snippets/blob/main/PowerShell/CopyDir.ps1)

### dan
