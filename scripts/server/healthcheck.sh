#!/bin/bash

CURRENT_SCRIPT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")";pwd)
TCA_SCRIPT_ROOT=${TCA_SCRIPT_ROOT:-"$(cd $(dirname $CURRENT_SCRIPT_PATH); pwd)"}
TCA_PROJECT_PATH=${TCA_PROJECT_PATH:-"$(cd "$(dirname $TCA_SCRIPT_ROOT)"; pwd)"}

MAIN_CELRY_STATUS=0
ANALYSIS_CELERY_STATUS=0

source $TCA_SCRIPT_ROOT/utils.sh
source $TCA_SCRIPT_ROOT/server/_base.sh

function check_result() {
    name=$1
    ret=$2
    if [ "$ret" = "true" ]; then
        LOG_INFO "$name: OK."
        return 0
    else
        LOG_ERROR "$name run failed."
        return 1
    fi
}

function check_main_server() {
    main_server_result=$( check_target_process_exist "main.gunicorn.conf.py")
    if [ "$main_server_result" = "true" ]; then
        return 0
    else
        return 1
    fi
}

function check_main_worker() {
    main_worker_result=$( check_target_process_exist "main_celery_worker.pid")
    if [ "$main_worker_result" = "true" ]; then
        return 0
    else
        return 1
    fi
}

function get_main_worker_log() {
    LOG_INFO "Check main worker log"
    worker_log=$( tail -n 100 $TCA_SERVER_MAIN_PATH/log/celery.log )
    LOG_INFO "$worker_log"
}

function get_main_worker_error_log() {
    LOG_WARN "Check main worker error log"
    error_log=$( tail -n 100 $TCA_SERVER_MAIN_PATH/worker_error.out )
    LOG_WARN "$error_log"
}

function check_main_beat() {
    main_beat_result=$( check_target_process_exist "main_celery_beat.pid")
    if [ "$main_beat_result" = "true" ]; then
        return 0
    else
        return 1
    fi
}

function get_main_beat_log() {
    LOG_INFO "Check main beat log"
    beat_log=$( tail -n 100 $TCA_SERVER_MAIN_PATH/log/celery.log )
    LOG_INFO "$beat_log"
}

function get_main_beat_error_log() {
    LOG_WARN "Check main beat error log"
    error_log=$( tail -n 100 $TCA_SERVER_MAIN_PATH/beat_error.out )
    LOG_WARN "$error_log"
}

function check_analysis_server() {
    analysis_server_result=$( check_target_process_exist "analysis.gunicorn.conf.py")
    if [ "$analysis_server_result" = "true" ]; then
        return 0
    else
        return 1
    fi
}

function check_analysis_worker() {
    analysis_worker_result=$( check_target_process_exist "analysis_celery_worker.pid")
    if [ "$analysis_worker_result" = "true" ]; then
        return 0
    else
        return 1
    fi
}

function get_analysis_worker_error_log() {
    LOG_WARN "Check analysis beat error log"
    error_log=$( tail -n 100 $TCA_SERVER_ANALYSIS_PATH/worker_error.out )
    LOG_WARN "$error_log"
}

function check_login_server() {
    login_server_result=$( check_target_process_exist "login.gunicorn.conf.py")
    if [ "$login_server_result" = "true" ]; then
        return 0
    else
        return 1
    fi
}

function check_file_server() {
    file_server_result=$( check_target_process_exist "file.gunicorn.conf.py")
    if [ "$file_server_result" = "true" ]; then
        return 0
    else
        return 1
    fi
}

function check_scmproxy_server() {
    scmproxy_result=$( check_target_process_exist "proxyserver.py")
    if [ "$scmproxy_result" = "true" ]; then
        return 0
    else
        return 1
    fi
}

function check_nginx() {
    nginx_result=$( check_target_process_exist "nginx")
    if [ "$nginx_result" = "true" ]; then
        return 0
    else
        return 1
    fi
}

function check_tca_local_status() {
    main_server_result=""
    main_worker_result=""
    main_beat_result=""
    analysis_server_result=""
    analysis_worker_result=""
    login_server_result=""
    file_server_result=""
    scmproxy_result=""
    nginx_result=""

    # 1.监测server各微服务是否启动
    check_main_server
    check_result "tca_main_server" "$main_server_result"
    check_analysis_server
    check_result "tca_analysis_server" "$analysis_server_result"
    check_login_server
    check_result "tca_login_server" "$login_server_result"
    check_file_server
    check_result "tca_file_server" "$file_server_result"

    # 2.监测server各微服务worker是否正常启动
    check_main_worker
    check_result "tca_main_worker" "$main_worker_result" || get_main_worker_error_log
    check_main_beat
    check_result "tca_main_beat" "$main_beat_result" || get_main_beat_error_log
    check_analysis_worker
    check_result "tca_analysis_worker" "$analysis_worker_result" || get_analysis_worker_error_log
    check_nginx
    check_result "tca_nginx" "$nginx_result"

    # 3.请求各服务健康状态探测接口，监测服务是否可用、异步任务是否可用等
    check_server_healthcheck_api
}

function get_tca_local_log() {
    LOG_INFO "====================================================================================================="
    LOG_INFO "| what shows below is paths of TCA services' log files"
    LOG_INFO "| please excute command `tail -n 100 <log path>` to show content"
    LOG_INFO "| if necessary, please screenshot and open a issue on GitHub: https://github.com/Tencent/CodeAnalysis/issues"
    LOG_INFO "====================================================================================================="

    LOG_INFO "tca main server log      : "$TCA_MAIN_SERVER_LOG
    LOG_INFO "tca main worker log      : "$TCA_MAIN_CELERY_WORKER_LOG
    LOG_INFO "tca main beat log        : "$TCA_MAIN_CELERY_BEAT_LOG
    LOG_INFO "tca analysis server log  : "$TCA_ANALYSIS_SERVER_LOG
    LOG_INFO "tca analysis worker log  : "$TCA_ANALYSIS_CELERY_WORKER_LOG
    LOG_INFO "tca file server log      : "$TCA_FILE_SERVER_LOG
    LOG_INFO "tca login server log     : "$TCA_LOGIN_SERVER_LOG
    LOG_INFO "tca scmproxy server log  : "$TCA_SCMPROXY_SERVER_LOG
}

#--------------------------------------------
# 各服务健康健康状态探测
#--------------------------------------------

### 通过健康探测接口探测各服务是否可访问、可访问db、可执行异步任务 ###
function check_server_healthcheck_api() {
    rm -rf $CURRENT_SCRIPT_PATH/healthcheck_*.txt

    check_main_by_healthcheck_api
    check_analysis_by_healthcheck_api
    check_login_by_healthcheck_api
    check_login_by_healthcheck_api
    check_file_by_healthcheck_api
    celery_status_detect
}

### 请求main服务健康探测接口 ###
function check_main_by_healthcheck_api() {
    file_path="$TCA_PROJECT_PATH/server/projects/main"
    current_timestamp=`date '+%s'`
    file_path="$file_path/healthcheck_$current_timestamp.txt"
    target="http://0.0.0.0:8000/main/healthcheck/?file_name=$current_timestamp"
    check_healcheck_api_res "main" $target
    check_healcheck_api_sync_task_res "main" $file_path
}

### 请求analysis服务健康探测接口 ###
function check_analysis_by_healthcheck_api() {
    file_path="$TCA_PROJECT_PATH/server/projects/analysis"
    current_timestamp=`date '+%s'`
    file_path="$file_path/healthcheck_$current_timestamp.txt"
    target="http://127.0.0.1:8002/healthcheck/?file_name=$current_timestamp"
    check_healcheck_api_res "analysis" $target
    check_healcheck_api_sync_task_res "analysis" $file_path
}

### 请求登陆服务login健康探测接口 ###
function check_login_by_healthcheck_api() {
    target="http://127.0.0.1:8003/healthcheck/"
    check_healcheck_api_res "login" $target
}

### 请求文件服务file健康探测接口 ###
function check_file_by_healthcheck_api() {
    target="http://127.0.0.1:8804/healthcheck/"
    check_healcheck_api_res "file" $target
}

### 校验健康探测接口请求状态码 ###
function check_healcheck_api_res() {
    service=$1
    target_url=$2
    ret_code=$(curl -I -s --connect-timeout 1 ${target} -w %{http_code} | tail -n1)
    if [[ "x$ret_code" == "x200" ]]; then
        LOG_INFO "[HealthCheckAPI] service $service db check pass"
    elif [[ "x$ret_code" == "x503" ]]; then
        error_exit "[HealthCheckAPI]service $service failed, reason might be db connection fail or database/table initialization fail"
    else
        if [ $service == "main" ]; then
            error_exit "[HealthCheckAPI] nginx or service main failed, please reload nginx or view logs to locate the issue"
        else
            error_exit "[HealthCheckAPI] service $service failed, please view logs to locate the issue"
        fi
    fi
}

### 校验健康探测接口异步任务执行结果 ###
function check_healcheck_api_sync_task_res() {
    service=$1
    file_path=$1
    
    for ((i=0; i<3; i++));
    do
        sleep 1
        if [ -f $file_path ]; then
            if [ $service == "main" ]; then
                MAIN_CELRY_STATUS=1
            else
                ANALYSIS_CELERY_STATUS=1
            fi
            return
        fi
    done
}

### 延时对celery状态进行探测 ###
function celery_status_detect() {
    if [[ $MAIN_CELERY_STATUS == 1 ]] && [[ $ANALYSIS_CELERY_STATUS == 1 ]]; then
        return
    fi
    LOG_INFO "[HealthCheckAPI] Start to detect celery status, this process may take 10 seconds, please wait patiently...\n"
    b=""
    i=0
    while [[ $i -le 100 ]]
    do
      printf "[%-50s] %d%% \r" "$b" "$i";
      sleep 0.2
      ((i=i+2))
      b+="#"
      main_ret=$(ps -aux |grep -c main_celery_worker)
      analysis_ret=$(ps -aux |grep -c analysis_celery_worker)
      if [[ $main_ret -gt 1 ]] && [[ $analysis_ret -gt 1 ]]; then
        LOG_INFO "[HealthCheckAPI] celery has started"
        return
      fi
    done

    LOG_ERROR "[HealthCheckAPI] celery启动异常，为确保TCA能够正常进行扫描，请查阅server/projects/main/log/main_celery.log、server/projects/analysis/log/analysis_celery.log等日志文件定位问题并处理"
    error_exit "[HealthCheckAPI] 若无法解决，请前往github提出issue并附带日志截图"
}