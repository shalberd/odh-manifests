*** Settings ***
Default Tags     OpenDataHub
Resource         ${RESOURCE_PATH}/ODS.robot
Resource         ${RESOURCE_PATH}/Common.robot
Resource         ${RESOURCE_PATH}/Page/ODH/JupyterHub/JupyterHubSpawner.robot
Resource         ${RESOURCE_PATH}/Page/ODH/JupyterHub/JupyterLabLauncher.robot

Library          DebugLibrary

Suite Setup      Begin ODH Web Test
Suite Teardown   End Web Test

*** Test Cases ***
Open ODH Dashboard
  [Documentation]   Logs into the ODH Dashboard and navigate to the notebook spawner UI

  Launch Jupyter From RHODS Dashboard Link
  Login To Jupyterhub  ${TEST_USER.USERNAME}  ${TEST_USER.PASSWORD}  ${TEST_USER.AUTH_TYPE}
  ${authorization_required} =  Is Service Account Authorization Required
  Run Keyword If  ${authorization_required}  Authorize jupyterhub service account
  Wait Until Page Contains  Start a notebook server

Can Spawn Notebook
  [Documentation]   Spawns the user notebook

  # We need to skip this testcase if the user has an existing pod
  Fix Spawner Status
  Capture Page Screenshot
  Spawn Notebook With Arguments  image=s2i-generic-data-science-notebook

Can Launch Python3 Smoke Test Notebook
  [Documentation]   Execute simple commands in the Jupyter notebook to verify basic functionality 

  Add and Run JupyterLab Code Cell in Active Notebook  import os
  Add and Run JupyterLab Code Cell in Active Notebook  print("Hello World!")
  Capture Page Screenshot

  JupyterLab Code Cell Error Output Should Not Be Visible

  Add and Run JupyterLab Code Cell in Active Notebook  !pip freeze
  Wait Until JupyterLab Code Cell Is Not Active
  Capture Page Screenshot

  #Get the text of the last output cell
  ${output} =  Get Text  (//div[contains(@class,"jp-OutputArea-output")])[last()]
  Should Not Match  ${output}  ERROR*
  Stop JupyterLab Notebook Server

# All of the keywords below are workarounds until official support for ODH automation is added to ods-ci
#TODO: Update ods-ci to support ODH builds of dashbaord and it's components
*** Keywords ***
Wait for ODH Dashboard to Load
    [Arguments]  ${dashboard_title}="Open Data Hub"   ${odh_logo_xpath}=//img[@alt="Open Data Hub Logo"]
    Wait For Condition    return document.title == ${dashboard_title}    timeout=15s
    Wait Until Page Contains Element    xpath:${odh_logo_xpath}    timeout=15s

Begin ODH Web Test
    # This is a duplicate of the Begin Web Test in ods-ci that does not default to hardcoded
    # text/assets from downstream
    [Documentation]  This keyword should be used as a Suite Setup; it will log in to the
    ...              ODH dashboard, checking that the spawner is in a ready state before
    ...              handing control over to the test suites.

    Set Library Search Order  SeleniumLibrary

    Open Browser  ${ODH_DASHBOARD_URL}  browser=${BROWSER.NAME}  options=${BROWSER.OPTIONS}
    Login To RHODS Dashboard  ${TEST_USER.USERNAME}  ${TEST_USER.PASSWORD}  ${TEST_USER.AUTH_TYPE}
    ${authorization_required} =  Is Service Account Authorization Required
    Run Keyword If  ${authorization_required}  Authorize jupyterhub service account
    Wait for ODH Dashboard to Load

    # Workaround for issues when the dashboard reports "No Components Found" on the initial load
    Wait Until Element Is Not Visible  xpath://h5[.="No Components Found"]   120seconds
    Wait Until Element Is Visible   xpath://div[@class="pf-c-card__title" and .="Jupyter"]/../div[contains(@class,"pf-c-card__footer")]/a   120seconds

    Launch Jupyter From RHODS Dashboard Link
    Login To Jupyterhub  ${TEST_USER.USERNAME}  ${TEST_USER.PASSWORD}  ${TEST_USER.AUTH_TYPE}
    Fix Spawner Status
    Go To  ${ODH_DASHBOARD_URL}


Verify Notebook Name And Image Tag
    [Documentation]    Verifies that expected notebook is spawned and image tag is not latest
    [Arguments]    ${user_data}

    @{notebook_details} =    Split String    ${userdata}[1]    :
    ${notebook_name} =    Strip String    ${notebook_details}[1]
    Spawned Image Check    image=${notebook_name}
    Should Not Be Equal As Strings    ${notebook_details}[2]    latest    strip_spaces=True
