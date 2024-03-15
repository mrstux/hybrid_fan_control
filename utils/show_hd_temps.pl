#!/usr/local/bin/perl

# This script is designed to control both the CPU and HD fans in a Supermicro X10 based system according to both
# the CPU and HD temperatures in order to minimize noise while providing sufficient cooling to deal with scrubs
# and CPU torture tests. 

# It relies on you having two fan zones.

# To use this correctly, you should connect all your PWM HD fans, by splitters if necessary to the FANA header. 
# CPU, case and exhaust fans should then be connected to the numbered (ie CPU based) headers.  This script will then control the
# HD fans in response to the HD temp, and the other fans in response to CPU temperature. When CPU temperature is high the HD fans.
# will be used to provide additional cooling, if you specify cpu/hd shared cooling.

# If the fans should be high, and they are stuck low, or vice-versa, the BMC will be rebooted, thus it is critical to set the
# cpu/hd_max_fan_speed variables correctly.

# NOTE: It is highly likely the "get_hd_temp" function will not work as-is with your HDs. Until a better solution is provided
# you will need to modify this function to properly acquire the temperature. Setting debug=2 will help.

# Tested with a SuperMicro X10-SRi-F, Xeon E5-1650v4, Noctua 120, 90 and 80mm fans in a Norco RPC-4224 4U chassis, with Seagate NAS drives.

# This script can be downloaded from : https://forums.freenas.org/index.php?threads/script-hybrid-cpu-hd-fan-zone-controller.46159/

# The script was originally based on a script by Kevin Horton that can be found at:
# https://forums.freenas.org/index.php?threads/script-to-control-fan-speed-in-response-to-hard-drive-temperatures.41294/page-3#post-282683

# More information on CPU/Peripheral Zone can be found in this post:
# https://forums.freenas.org/index.php?threads/thermal-and-accoustical-design-validation.28364/

# stux

# VERSION HISTORY
#####################
# 2016-09-19 Initial Version
# 2016-09-19 Added cpu_hd_override_temp, to prevent HD fans cycling when CPU fans are sufficient for cooling CPU

###############################################################################################
## CONFIGURATION
################

## DEBUG LEVEL
## 0 means no debugging. 1,2,3,4 provide more verbosity
## You should run this script in at least level 1 to verify its working correctly on your system
$debug = 2;


################
## MISC
#######

## IPMITOOL PATH
## The script needs to know where ipmitool is
$ipmitool = "/usr/local/bin/ipmitool";

## HD POLLING INTERVAL
## The controller will only poll the harddrives periodically. Since hard drives change temperature slowly
## this is a good thing. 180 seconds is a good value.
$hd_polling_interval = 180;	# seconds

## FAN SPEED CHANGE DELAY TIME
## It takes the fans a few seconds to change speeds, we allow a grace before verifying. If we fail the verify
## we'll reset the BMC
$fan_speed_change_delay = 10; # seconds

## BMC REBOOT TIME
## It takes the BMC a number of seconds to reset and start providing sensible output. We'll only
## Reset the BMC if its still providing rubbish after this time.
$bmc_reboot_grace_time = 120; # seconds

## BMC RETRIES BEFORE REBOOTING
## We verify high/low of fans, and if they're not where they should be we reboot the BMC after so many failures
$bmc_fail_threshold	= 1; 	# will retry n times before rebooting

# edit nothing below this line
########################################################################################################################

use POSIX qw(strftime);

# GLOBALS
@hd_list = get_hd_list();

get_hd_temp( hd_list );

sub get_hd_list
{
	my $disk_list = `camcontrol devlist | sed 's:.*(::;s:).*::;s:,pass[0-9]*::;s:pass[0-9]*,::' | egrep '^[a]*da[0-9]+\$' | tr '\012' ' '`;
	dprint(3,"$disk_list\n");

	my @vals = split(" ", $disk_list);
	
	foreach my $item (@vals)
	{
		dprint(2,"$item\n");
	}

	return @vals;
}

sub get_hd_temp
{
	my $max_temp = 0;
	
	foreach my $item (@hd_list)
	{
		my $disk_dev = "/dev/$item";
		my $command = "/usr/local/sbin/smartctl -A $disk_dev | grep Temperature_Celsius";
 		
		dprint( 3, "$command\n" );
		
		my $output = `$command`;

		dprint( 2, "$output");

		my @vals = split(" ", $output);

		# grab 10th item from the output, which is the hard drive temperature (on Seagate NAS HDs)
  		my $temp = "$vals[9]";
		chomp $temp;
		
		if( $temp )
		{
			dprint( 1, "$disk_dev: $temp\n");
			
			$max_temp = $temp if $temp > $max_temp;
		}
	}

	dprint(0, "Maximum HD Temperature: $max_temp\n");

	return $max_temp;
}


sub build_date_string
{
	my $datestring = strftime "%F %H:%M:%S", localtime;
	
	return $datestring;
}

sub dprint
{
	my ( $level,$output) = @_;
	
#	print( "dprintf: debug = $debug, level = $level, output = \"$output\"\n" );
	
	if( $debug > $level ) 
	{
		my $datestring = build_date_string();
		print "$datestring: $output";
	}

	return;
}










