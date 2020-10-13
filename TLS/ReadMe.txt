Description :
The powershell scripts in this folder are used to apply TLS 1.2 to IWS APP and DB Server.

Note:  In order to apply these scripts a combo machine i.e a machine on which both IWS App and DB is installed cannot be used.
The DB and App servers need to be separate.

Pre-requisites:
DB SQL Server 2012
Enforce Encryption 
Please see the link on steps for how to Enforce Encryption:
https://ewiki.athoc.com/display/QA/Enable+Secure+Communication+between+IWS+Application+and+Database+Server


Steps to enable TLS on App and DB: 

1.Copied the scripts from  Subversion location: https://svn.athoc.com/athoc/etc/eng/build/Security/TLS

2. Run the PowerShell script on DB and App

3. Validated on DB server and App server
  
  Open Regedit : HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\
  Validate the values for Server and Client as per the power shell
   

To test TLS 1.2 is enforced

From Browser settings (IE)  :

1. Uncheck TLS1.2
Access the server , should give an error " This page can't be displayed, Turn on TLS ..."

2. Check TLS 1.2
Access the server, should be able to connect



