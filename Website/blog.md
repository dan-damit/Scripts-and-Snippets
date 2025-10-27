# Manifest-Driven Markdown
**Date:** 2025-10-24  
**Tags:** markdown, automation
## The structure is as follows:

Started structuring the blog page to reflect my engineering mindset.  
Markdown parsing is next.

Use a blog.md file to document blog posts.
Each post starts with metadata: date and tags.
Posts are separated by horizontal rules (---).
Content can include headings, paragraphs, lists, and code snippets.
Node.js script will parse this file and generate HTML in a JSON for the blog page.
md-to-json.js will read blog.md, parse it, and output entry.json.
blog-loader.js will read entry.json and render the blog page.

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

`Invoke-TrumpWrongGIF...`

LinkedIn was having none of it. After some digging, I discovered a page on the LinkedIn site 
that would render how a post would look. This little tool was super helpful, and pointed me 
toward the `robots.txt` file tied to my URL. The kicker was... no such file existed in the 
File Station `/volume1/web/`.

At this point I SSH to my NAS, and I find 5 total files named `robots.txt` all living in 
nginx.conf. So I `sudo vi` into the conf and inspect them. I modified them to say `Allow /` 
instead of `Disallow /`, and restart nginx...

Alas, no change... Still disallow.

Now I'm starting to flex my Google-fu 3rd degree blackbelt combined with Copilot to see 
how this DSM generates this `nginx.conf`.

After a few hours ... yes, hours ... of looking and digging around in the SSH, and with 
the help of trusty Google and Copilot combo, I discover the `nginx.conf` is generated dynamically 
at service startup, but there is one overriding little piece in a hidden `usr` dir.

DSM has a hidden user dir: `/usr/syno` that houses numerous automation and conf files.  
A quick `grep` for `robots.txt` in `/usr/syno/` location revealed the culprit.  
A `sudo vi /usr/syno/share/nginx/optimization.mustache` concealed a snippet that had this:

location = /robots.txt { allow all; access_log off; log_not_found off; }

After swapping that for this:

location = /robots.txt { root /volume1/web; default_type text/plain; }

(Which is my custom robots.txt file in the root web folder), BOOM!
Disallow / became Allow / and loading into LinkedIn was possible...after restarting nginx 
again of course.

So hopefully this helps someone out there,
### dan

---

# Automating Blog Generation
**Date:** 2025-10-25
**Tags:** automation, blogging
## The workflow is as follows:

Started automating blog generation using Node.js scripts to parse markdown and generate HTML.
The plan is to create a seamless workflow for adding new blog posts.

1. Write blog posts in `blog.md` using markdown syntax.
2. Run `md-to-json.js` to parse `blog.md` and generate `entries.json`.
3. Use `blog-loader.js` to read `entry.json` and render the blog page
4. Created Scheduled Task using Synology DSM to automate running `md-to-json.js` every 15 minutes.
5. Which deploys the updated blog page to the website.

All the code is on my GitHub if anyone wants to check it out.
I'm currently working on the `watch-blog.js` to monitor changes in real-time.

I love being nerdy like this!
### dan

---

# Building This Website
**Date:** 2025-10-26
**Tags:** coding, server, networking
## Below are some thoughts on the process:

Started with an idea to have a centralized resume to eliminate juggling dozens of file versions.
Easier this way to manage formatting and versioning.

I had to figure out how to get the server alias portal setup in DSM ... Synology's DSM
is pretty unique. I didn't want it to interfere with the DSM interface and site, so
the alias of /dan/ was a good compromise. 

The site files are all housed in that dir. /volume1/web is the default webserver dir, so the
alias lived in my folder /dan.

/volume1/web/dan/

Setting up the alias web portal under the Web Service tab in Web Station was pretty straight 
forward. Create a static site with your alias and point it at whatever dir you decide on. 
After that, just make sure your folder allows http user read access to the folder.

Obviously, you'll need to port forward 80 and 443 to your webserver. I ended up setting up a 
Reverse Proxy in DSM to handle all 80 and 443 requests and route them to internal apps.
Firewall hardening on the webserver is highly recommended as well. I will be making a post
about that in the coming days.

## Coding the site:

It started with just resume.html...just laying down the framework for the styling to come next.
I brainstormed a 'north star' sort of theme that I wanted the entire site to follow. I 
settled on my favorite movie trilogy (if the theme isn't obvious at this point then you've 
been living under a rock lol). THE MATRIX. Then, I created the central matrix-theme.css and 
built on top of that with the little JavaScript file to handle the matrix-rain.js effect in 
the background on my entire site. Google and Copilot came in handy to find all, or most,
of the characters used in the film.

Coding this blog was probably my favorite nerd hack. I automated the process (and documented 
it in a previous post) where all I need to do is update the blog.md file and save to the server.
The automated task runs my md-to-json.js script to parse it into a json that is easily digestable
by HTML. 

My next favorite was making a print-resume.css and a new button on the resume.html 
that renders a very recruiter friendly version. Clicking the Download PDF button opens a 
browser print window with the specialized recruiter friendly version.

From the style of Baudrillard, the link in the upper right corner was my tip of the cap. In 
one of the first chapters of the first film, Neo has his programs hidden in a book by Baudrillard. 

'Welcome to the desert of the real...'

I tought the connection between that book by Baudrillard and the film trilogy is uncanny.

Anyway, all in all, this has been a super fun project to work on that took a lot of planning, and 
research. Trial and error. Not to mention some late nights coding and debugging. Totally worth it!

All my code is posted on my GitHub!
Please feel as free as Zion after Smith's destruction to reach out!
### dan

---

# Securing Synology DSM
**Date:** 2025-10-26
**Tags:** security, server, firewall
## Documented my Synology DSM hardening process to enhance security.

Started with basic firewall rules, then moved to advanced settings.

### The steps taken are as follows:

1. Enabled Synology's built-in firewall and created and made a rule set to deny all 
	incoming traffic by default and keep it at the bottom of the rule list.

2. Created allow rules for only necessary services (e.g., SSH, HTTPS, HTTP) from
	specific IP addresses or ranges; change from default SSH port to something obscure.

3. Created GeoIP blocking rules to deny traffic from high-risk countries.
	Put this one at the top of the rule list.

4. Disabled unused services to minimize attack surface.

5. Enabled 2FA for all user accounts to add an extra layer of security.

6. Disabled default admin account and created a new admin user with a strong password.

7. Regularly updated DSM and installed packages to ensure all security patches

More to come soon on details of each step.
### dan