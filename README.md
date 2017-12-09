# wifi-presence-detector

wifi-presence-detector is a bash script that checks the local network for the presence of devices matching known MAC addresses, and send s events to [IFTTT](https://ifttt.com) webhooks.  

Such events could probably be used in any number of ways by your IFTTT applets, but I'll focus on how they can be used to flip the status on a virtual switch on a Samsung Smart Things hub.  wifi-presence-detector does not track individuals; rather, it tracks two states: "someone is home" and "no one is home", based on whether it can match any devices on the network to a list of known MAC addresses.  In practice, I'm using this to determine whether I should be terribly worried about that door sensor opening, based on whether a phone belonging to someone I know is in the house (without giving them full access to all the smart home devices, which is a prerequisite for the built-in Smart Things phone-based presence tracking).

## Setup
TODO: Add much more detail; most of these are placeholders

### Set up Smart Things
- Set up a virtual switch (or a virtual presence detector?  I've heard of these things but haven't tried this yet.)

### Set up IFTTT
- create an account if you don't have one
- get your maker webhook API key thing
- make one applet to receive the `no_one_home` event, and another applet to receive the `someone_home` event, and set each of them up to flip your Smart Things virtual switch in the appropriate direction

### Install Dependencies
```
# or the package manager of your choice
sudo apt-get update -y && sudo apt-get install -y flock curl
```

### Set up wifi-presence-detector
Ideally, wifi-presence-detector will run on a machine that's always on and connected to your network (wireless or wifi shouldn't matter).  I'm running it on a raspberry pi running raspbian linux but, it can probably be made to work on OSX or other Linux distros.

- clone or download the repo, then:

```
cd wifi-presence-detector

# Copy some files into place
cp .env.example .env
cp known_mac_addresses.example known_mac_addresses
```

- Edit your .env file as needed


The .env file contains some sane defaults. Of these, only `WPD_IFTTT_WEBHOOK_KEY` is required: this is the API key for your IFTTT webhook.  `WPD_SCAN_SUBNET` is the range of IP addresses that the script will scan, so make sure that's correct. 

You can also set these as environment variables if that's more your thing.  If you do that, keep in mind that the script will always try to source and use values from the .env file, so if you're setting env variables yourself make sure to delete the corresponding lines from the .env file as those will take precendence. 

Customizable variables in the .env file:

```
WPD_IFTTT_WEBHOOK_KEY='' # REQUIRED! Create an IFTTT Maker Webhook to get one.
WPD_LOCKFILE=/tmp/scan_network.lock
WPD_LOGFILE=scan.log
WPD_CONSECUTIVE_EMPTY_RESULT_THRESHOLD=20 # The number of consecutive scans that must come up empty before marking the house unoccupied
WPD_SLEEP_INTERVAL=5 # The time to wait between scans
WPD_SCAN_SUBNET=192.168.1.1/24 # The network addresses to scan. Both CIDR and stuff like 192.168.1.1-254 seem to work
```

- Optionally, set up a cron job to run the script.

You can have it run every minute, as in the example cron file. The script uses flock to make sure only one copy of itself is running at a time.  Once it's in place, edit the cron file to point to the actual location of your wifi-presence-detector.sh script

```
sudo cp wifi-presence-detector.cron.example /etc/cron.d/wifi-presence-detector && sudo chown root:root /etc/cron.d/wifi-presence-detector 
```

- Add known MAC addresses to your `known_mac_addresses` file, one per line, case insensitive.
These are probably the MAC addresses of the wireless adapters of mobile handsets, to make them useful for presence info.  You can probably find MAC addresses you might be interested in by logging in to your router to see connected devices, or with `nmap` or something 

### Test your IFTTT webhook
You can use `test_post_to_ifttt.sh` to test your IFTTT webhook.  You'll need WPD_IFTTT_WEBHOOK_KEY to be set in your .env file.

```
./test_post_to_ifttt.sh someone_home
./test_post_to_ifttt.sh no_one_home
```

## Run it!

Run it from the command line.  This will background the process, where it will run continuously.  The script uses `flock` to ensure that only one copy of itself can be running at one time, so you (or cron) can fire up as many copies as you want, but they'll quit while the original stays running.

```
sudo ./wifi-presence-detector.sh &
```

Or, if you set up a cron job, just let cron take care of it!  This has the advantage(?) of re-running the script if it dies or your machine reboots, etc.

To kill a backgrounded or cron-initiated script:

```
sudo pkill -f wifi-presence-detector.sh
```

Much credit for inspiration is due to [this blog post](http://handyharley.blogspot.com/2017/08/flip-virtual-switch-in-smartthings-when.html)
