##################################################################
# author:           $Author: codebldr $
# date:             $DateTime: 2024/02/28 08:24:46 $
# Revision:         $Revision: #1 $
# file:             $File: //streams_rgs_games_einstant/eInstantJuicyWinsWLA-mainline/CM/deploy/fabfile.py $
#
# Purpose:          Fabric Deployment script for RGS DDI project
#
##################################################################
from fabric.api import *
from fabric.contrib.project import *
from fabric.colors import green,red
from fabric.contrib.files import exists

import os
import re

g_apache_root='/wworks/ipl/apache'

########################################################################
# Internal Helper Functions
def CreateDirectoryIfNotExist(path):
    ''' Check and create (path) in remote host if it does not exist '''
    if not exists(path):
        run('mkdir -p %s' % path)

########################################################################
@runs_once
def GetGamesList(game_dir):
    return [f for f in os.listdir(game_dir) if re.search(r'[0-9]+\-[0-9]+\-[0-9]+', f)]

@runs_once
def GetGamesList_jBcs_jLottery(game_dir):
    return [f for f in os.listdir(game_dir)]


# Fabric Tasks
@task
def ControlWebServers(envir, service="stop"):
    apache_dir = os.path.join(g_apache_root, envir)

    ''' Stop/Start web servers '''
    apache_bin_path = os.path.join(apache_dir, 'bin')
    with cd(apache_bin_path):
        if exists('run_apache.bash'):
            run('chmod u+x run_apache.bash')
            if service.lower()=="stop":
                run('./run_apache.bash stop')
            elif service.lower()=="start":
                run('nohup ./run_apache.bash start | tee ../logs/nohup.out')
            else:
                error('Invalid service type')
        else:
            run('echo run_apache.bash does not exist! Possibility first deloyment')


@task
def InstallGame(envir):
    current_dir = os.path.dirname(os.path.realpath(__file__))

    extracted_game_root = os.path.join(current_dir, r'../../package')
    for dir in os.listdir(extracted_game_root):
        extracted_game_dir = os.path.join(extracted_game_root, dir)
        extracted_locale_dir = os.path.join(extracted_game_dir, 'locale')

        game_root = os.path.join(os.path.join(g_apache_root, envir), 'htdocs')
        game_root = os.path.join(game_root, dir)
        locale_root = os.path.join(game_root, 'locale')

        extracted_game_paymodel_list = GetGamesList(extracted_game_dir)
        for game_paymodel_id in extracted_game_paymodel_list:
            source = os.path.join(extracted_game_dir, game_paymodel_id)
            dest = os.path.join(game_root, game_paymodel_id)
            CreateDirectoryIfNotExist(dest)
            local("rsync -av --delete --rsh='ssh -p 22' %s %s:%s" % (source+"/", env.host_string, dest))

            locale_source = os.path.join(extracted_locale_dir, game_paymodel_id)
            locale_dest = os.path.join(locale_root, game_paymodel_id)
            CreateDirectoryIfNotExist(locale_dest)
            local("rsync -av --delete --rsh='ssh -p 22' %s %s:%s" % (locale_source+"/", env.host_string, locale_dest))


@task
def InstalljBcs_jLottery(envir):
    current_dir = os.path.dirname(os.path.realpath(__file__))
    extracted_game_root = os.path.join(current_dir, r'../../package')
    for dir in os.listdir(extracted_game_root):
        extracted_game_dir = os.path.join(extracted_game_root, dir)
        game_root = os.path.join(os.path.join(g_apache_root, envir), 'htdocs')
        game_root = os.path.join(game_root, dir)
        extracted_game_paymodel_list = GetGamesList_jBcs_jLottery(extracted_game_dir)
        for game_paymodel_id in extracted_game_paymodel_list:
            source = os.path.join(extracted_game_dir, game_paymodel_id)
            dest = os.path.join(game_root, game_paymodel_id)
            CreateDirectoryIfNotExist(dest)
            local("rsync -av --delete --rsh='ssh -p 22' %s %s:%s" % (source+"/", env.host_string, dest))




@task
@runs_once
def ResetAppServerTemplate(envir):
    apache_dir = os.path.join(g_apache_root, envir)
    apache_bin_path = os.path.join(apache_dir, 'bin')

    with cd(apache_bin_path):
        if exists('clear_cache.py'):
            result = run("python clear_cache.py --env ipl-{0}".format(envir))
            if result.failed:
                print(red('\tUnable to clear App Server Cache'))
            else:
                print(green('\tSuccessfully cleared App Server Cache'))

@task
def RollingInstallGame(envir):
    ControlWebServers(envir,'stop')
    InstallGame(envir)
    ControlWebServers(envir,'start')

@task
def RollingInstalljLottery(envir):
    ControlWebServers(envir,'stop')
    InstalljBcs_jLottery(envir)
    ControlWebServers(envir,'start')
