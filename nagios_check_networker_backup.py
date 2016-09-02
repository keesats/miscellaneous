#!/usr/bin/python
# -*- coding: iso-8859-15 -*-
# 
from pynagios import Plugin, Response, make_option
import datetime
import re
import subprocess
import os
from signal import alarm, signal, SIGALRM, SIGKILL, getsignal
import sys

class MyCheck(Plugin):
    """nagios check plugin that returns the state of the savesets of the last
    day by using the mminfo binary of the legato client.
    the legato client has to be installed and configured properly.
    try to execute a mminfo command separatly before.
    i.e.: /mminfo -o n -s serverxy -q "client='clientxy',savetime>=last day" -r
    "client,name,savetime(17),nsavetime,level"

    usage:
    -H = Hostname in fqn or normal form (no ip address)
    --server = Name or IP of the networker server
    --timeout = timeout value for killing the mminfo process
    """

    server = make_option("--server",type="string")

    def check(self):

        class AlarmError(Exception):
            pass

        def alarm_handler(signum, frame):
            raise AlarmError

        def get_process_children(pid):
            args = [
                    'ps',
                    '--no-headers',
                    '-o',
                    'pid',
                    '--ppid',
                    pid ]
            p = subprocess.Popen(args, stdout=subprocess.PIPE,
                                 stderr=subprocess.PIPE, env={'LANG':'de_DE@euro'})
            stdout, stderr = p.communicate()
            return [int(p) for p in stdout.split()]
        ## timeout
        timeout = self.options.timeout
        ## kill_tree
        kill_tree = True
        #servername = 'nsr_srv'
        servername = self.options.server
        ## get the hostname
        hostname = self.options.hostname
        ## search for a dot in possibly full qualified hostname
        m = re.search(r"(.*)\.(.*)", hostname)
        ## if search succesfull
        if m != None:
            ## extract hostname
            hostname_fields = hostname.split(".")
            hostname = hostname_fields[0]
        # mminfo command
        queryspec = "client='%s',savetime>=last day" %  hostname
        reportspec = "client,name,savetime(17),nsavetime,level,ssflags"
        args = [
                '/usr/sbin/mminfo',
                '-o', 'n',
                '-s', servername,
                '-q', queryspec,
                '-r', reportspec,
                '-x', 'c;'
                ]
        args2 = [
                'ping',
                'localhost',
                '-c 10',
                ]
        ## create a subprocess with LANG=de_DE@euro
        process = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env={'LANG':'de_DE@euro'})
        processpid = process.pid
        ## create a alarm with timeout parameter
        if timeout != -1:
            signal(SIGALRM, alarm_handler)
            alarm(timeout)
        try:
            ## catch stdout and stderr
            output = process.communicate()
            ## get current date and convert it to special form
            today = datetime.datetime.today()
            today_2 = today.strftime('%d.%m.%Y')
            yesterday = today - datetime.timedelta(days=1)
            yesterday = yesterday.strftime('%d.%m.%Y')
            lines = str(output[0]).strip("\n").split("\n")
            lines2 = ''.join(str(output[1]).strip("\n").split("\n"))
            del lines[0]
            anzahl_lines = len(lines)
            #nr = 0
            errorcounter = 0
            liste = []
            ## If no output in stdout, then ...
            no_data = '6095:mminfo: no matches found for the query'
            if anzahl_lines < 1 and lines2 == no_data:
                info =  "The query has no results."
                liste.append(info)
            else:
                for line in lines:
                    #nr = nr + 1
                    fields = line.split(";")
                    date_full = fields[2].split()
                    date = date_full[0]
                    time = date_full[1]
                    ssflag = fields[5]
                    if ssflag == 'vF':
                        state = 'no errors.'
                    elif ssflag == 'I':
                        state = 'working'
                    elif ssflag != '':
                        state = "with flags " + ssflag
                    if date == yesterday or date == today_2:
                        info = "'" + fields[1] + "' " + date + ", " + \
                        time  + " , backup level: \"" + fields[4] + "\" => " + state + "\n"
                        liste.append(info)
                    else:
                        errorcounter = errorcounter + 1
                        info = "'" + fields[1] + "' " + date + ", " + \
                        time  + " , backup level: \"" + fields[4] + "\" => " + state + "\n"
                        liste.append(info)
            if timeout != -1:
                ## alarm reset to null
                alarm(0)
        except AlarmError:
            pids = [process.pid]
            if kill_tree:
                pids.extend(get_process_children(pid))
            for pid in pids:
            # process might have died before getting to this line
            # so wrap to avoid OSError: no such process
                try:
                    os.kill(pid, SIGKILL)
                except OSError:
                    pass
            return -9, '', ''

        # Return a response
        finaloutput = "".join(liste).strip("\n")
        #print finaloutput
        if errorcounter > 1:
            errorcounter = 1
        result = self.response_for_value(errorcounter, message=finaloutput)
        return result


if __name__ == "__main__":
# Instantiate the plugin, check it, and then exit
    MyCheck().check().exit()
