#!/bin/bash

source $TEST_DIR/common

MY_DIR=$(readlink -f `dirname "${BASH_SOURCE[0]}"`)

source ${MY_DIR}/../util

TEST_USER=${OPENSHIFT_TESTUSER_NAME:-"admin"} #Username used to login to the ODH Dashboard
TEST_PASS=${OPENSHIFT_TESTUSER_PASS:-"admin"} #Password used to login to the ODH Dashboard
OPENSHIFT_TESTUSER_LOGIN_PROVIDER=${OPENSHIFT_TESTUSER_LOGIN_PROVIDER:-"htpasswd-provider"} #OpenShift OAuth provider used for login
ODS_CI_REPO_ROOT=${ODS_CI_REPO_ROOT:-"${HOME}/src/ods-ci"}
OPENSHIFT_OAUTH_ENDPOINT="https://$(oc get route -n openshift-authentication   oauth-openshift -o json | jq -r '.spec.host')"
ODH_DASHBOARD_URL=

os::test::junit::declare_suite_start "$MY_SCRIPT"

function check_resources() {
    header "Testing dashboard installation"
    os::cmd::expect_success "oc project ${ODHPROJECT}"
    os::cmd::try_until_text "oc get odh-dashboard odh-dashboard" "odh-dashboard" $odhdefaulttimeout $odhdefaultinterval
    os::cmd::try_until_text "oc get crd odhdashboardconfigs " "odhdashboardconfigs" $odhdefaulttimeout $odhdefaultinterval
    os::cmd::try_until_text "oc get role odh-dashboard" "odh-dashboard" $odhdefaulttimeout $odhdefaultinterval
    os::cmd::try_until_text "oc get rolebinding odh-dashboard" "odh-dashboard" $odhdefaulttimeout $odhdefaultinterval
    os::cmd::try_until_text "oc get route odh-dashboard" "odh-dashboard" $odhdefaulttimeout $odhdefaultinterval
    ODH_DASHBOARD_URL="https://"$(oc get route odh-dashboard -o jsonpath='{.spec.host}')
    os::cmd::try_until_text "oc get service odh-dashboard" "odh-dashboard" $odhdefaulttimeout $odhdefaultinterval
    os::cmd::try_until_text "oc get deployment odh-dashboard" "odh-dashboard" $odhdefaulttimeout $odhdefaultinterval
    os::cmd::try_until_text "oc get pods -l deployment=odh-dashboard --field-selector='status.phase=Running' -o jsonpath='{$.items[*].metadata.name}' | wc -w" "2" $odhdefaulttimeout $odhdefaultinterval
}

function check_rest_api() {
    header "Testing dashboard Rest API"
    os::cmd::expect_success "oc project ${ODHPROJECT}"

    # The odh-dashboard oauth-proxy enables openshift-delegate-urls and requires any user querying the rest api directly has read access to service/odh-dashboard
    oc adm policy add-role-to-user view -n ${ODHPROJECT} --rolebinding-name "view-$TEST_USER" $TEST_USER

    # Since the openshift-ci environ runs under `system:admin` with no assigned oauth token we need to retrieve the oauth token for the test user via the oauth REST API
    # See https://access.redhat.com/solutions/6610781
    local TESTUSER_BEARER_TOKEN="$(curl -skiL -u $TEST_USER:$TEST_PASS -H 'X-CSRF-Token: xxx' '$OPENSHIFT_OAUTH_ENDPOINT/oauth/authorize?response_type=token&client_id=openshift-challenging-client' | grep -oP 'access_token=\K[^&]*')"

    os::log::info "$ODH_DASHBOARD_URL"
    # Simple check to verify the Dashboard route returns valid html
    os::cmd::try_until_text "curl -k -H 'Authorization: Bearer ${TESTUSER_BEARER_TOKEN}' $ODH_DASHBOARD_URL" "<title>Open Data Hub</title>" $odhdefaulttimeout $odhdefaultinterval
    # Check the the rest api is available
    os::cmd::try_until_text "curl -k -s -H 'Authorization: Bearer ${TESTUSER_BEARER_TOKEN}' -o /dev/null -w \"%{http_code}\" $ODH_DASHBOARD_URL/api/components" "200" $odhdefaulttimeout $odhdefaultinterval
    # Check that the default Jupyter component is available
    os::cmd::try_until_text "curl -k -H 'Authorization: Bearer ${TESTUSER_BEARER_TOKEN}' $ODH_DASHBOARD_URL/api/components | jq '.[].metadata.name'" "jupyter" $odhdefaulttimeout $odhdefaultinterval
}

function test_odh_dashboard_ui() {
    header "Running ODS-CI automation"

    os::cmd::expect_success "oc project ${ODHPROJECT}"
    pushd ${HOME}/src/ods-ci
    #TODO: Add a test that will iterate over all of the notebook using the notebooks in https://github.com/opendatahub-io/testing-notebooks
    # Execute the ods-ci robotframework automation to verify that we can spawn a notebook
    os::cmd::expect_success "run_robot_test.sh --skip-oclogin true --test-artifact-dir ${ARTIFACT_DIR} \
      --test-case ${MY_DIR}/../resources/ods-ci/test-odh-dashboard-jupyterlab-notebook.robot \
      --test-variables-file ${MY_DIR}/../resources/ods-ci/test-variables.yml \
      --test-variable 'ODH_DASHBOARD_URL:${ODH_DASHBOARD_URL}' \
      --test-variable RESOURCE_PATH:${PWD}/tests/Resources \
      --test-variable TEST_USER.USERNAME:${TEST_USER} \
      --test-variable TEST_USER.PASSWORD:'${TEST_PASS}' \
      --test-variable TEST_USER.AUTH_TYPE:${OPENSHIFT_TESTUSER_LOGIN_PROVIDER}"
    popd
}

check_resources
# Disabling the REST API check because it requires that the user account has cluster-admin permissions
# This test should be re-enabled when https://github.com/opendatahub-io/odh-dashboard/issues/548 is resolved
#check_rest_api
test_odh_dashboard_ui

os::test::junit::declare_suite_end
