# Manifest-Driven Markdown
**Date:** 2025-10-24  
**Tags:** markdown, automation

Started structuring the blog page to reflect my engineering mindset.  
Markdown parsing is next.

### The structure is as follows:

Use a blog.md file to document blog posts.
Each post starts with metadata: date and tags.
Posts are separated by horizontal rules (---).
Content can include headings, paragraphs, lists, and code snippets.
Node.js script will parse this file and generate HTML in a JSON for the blog page.
md-to-json.js will read blog.md, parse it, and output entry.json.
blog-loader.js will read entry.json and render the blog page.

---

# Synology Config Override
**Date:** 2025-10-25  
**Tags:** diagnostics, server

Documented the robots.txt override fix for Synology. Planning to blog the diagnostic process.

### The process is below:

The issue I was having was related to how my NAS builds the nginx config files.  
Okay let me back up a bit... I have a Synology DS720+ that hosts all of my stuff... media, backups, files... this website, etc.  
I wanted to link my landing page to LinkedIn's Featured section. No biggie!

`Invoke-TrumpWrongGIF...`

LinkedIn was having none of it. After some digging, I discovered a page on the LinkedIn site that would render how a post would look.  
This little tool was super helpful, and pointed me toward the `robots.txt` file tied to my URL.  
The kicker was... no such file existed in the File Station `/volume1/web/`.

At this point I SSH to my NAS, and I find 5 total files named `robots.txt` all living in nginx.conf.  
So I `sudo vi` into the conf and inspect them. I modified them to say `Allow /` instead of `Disallow /`, and restart nginx...

Alas, no change... Still disallow.

Now I'm starting to flex my Google-fu 3rd degree blackbelt combined with Copilot to see how this DSM generates this `nginx.conf`.

After a few hours ... yes, hours ... of looking and digging around in the SSH, and with the help of trusty Google and Copilot combo, 
I discover the `nginx.conf` is generated dynamically, but there is one overriding little piece in a hidden `usr` dir.

DSM has a hidden user dir: `/usr/syno` that houses numerous automation and conf files.  
A quick `grep` for `robots.txt` in `/usr/syno/` location revealed the culprit.  
A `sudo vi /usr/syno/share/nginx/optimization.mustache` concealed a snippet that had this:

location = /robots.txt { allow all; access_log off; log_not_found off; }

After swapping that for this:

location = /robots.txt { root /volume1/web; default_type text/plain; 

(Which is my custom robots.txt file in the root web folder), BOOM!
Disallow / became Allow / and loading into LinkedIn was possible—after restarting nginx again of course.

So hopefully this helps someone out there,
dan