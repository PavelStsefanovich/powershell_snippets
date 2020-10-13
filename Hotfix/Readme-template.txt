_____________________________________________
PREREQUISITES:

  - Powershell 3.0 
	Windows Management Framework
	https://www.microsoft.com/en-us/download/details.aspx?id=34595

  - SQLCMD
	(This is required to be installed on Application server for systems with one application server and one database server (see 6.a below),
	as well as on FIRST Application server for systems with multiple application servers and database on separate machine (see 6.b below).
	For combo systems with application and database on single machine installation is NOT required as SQLCMD is part of MSSQLServer installation.
	Please close and reopen Powershell window after installation.)

	Microsoft ODBC Driver (MSODBCSQL)
	https://www.microsoft.com/en-us/download/details.aspx?id=36434

	Microsoft Command Line Utilities (SQLCMD)
	https://www.microsoft.com/en-us/download/details.aspx?id=52680

_____________________________________________
TO APPLY HOTFIX:


1) !! IMPORTANT: Make sure that Hotfix (ZIP file) is unblocked:
   - Right click ZIP file
   - Click Properties
   - Go to the "General" tab
   - Click on "Unblock file"
   - Click OK

2) Unzip hotfix package

3) Open Powershell.exe as administrator

4) Allow script execution:
	> Set-ExecutionPolicy Unrestricted (type 'y'-> enter when prompted)

5) Navigate to the folder where script is located:
	> cd "c:\someFolder\HF-xxx(6.1.8.xxx)"

6) Run script:
	a) for systems with one application server and one database server,
	   as well as for combo systems with application and database on single machine,
	   run from Application server (MSODBCSQL and SQLCMD required, if not combo system):

	   > .\Install.ps1	

	b) for systems with multiple application servers and database on separate machine,
           on first application server run to upgrade both Application server and Database sever
	   (MSODBCSQL and SQLCMD required):

           > .\Install.ps1

           on rest of the application servers use value "Application" for -Server parameter to update only application server
	   (MSODBCSQL and SQLCMD not required):
              
	   > .\Install.ps1 -Server Application

7) Repeat installation steps for each application server, if there are more than one app server for a cloud system.

8) Run the below query and ensure that data shows up to confirm that hotfix is present. Ensure that you have logged into the correct cloud database.
 
	> select * from ngaddata.dbo.sys_product_hotfix_tab (nolock) where hot_fix_id = ? <Replace with exact HF # per hotfix>

_____________________________________________
TO EXECUTE ROLLBACK:

- Application server Rollback will be executed only if the installation attempt was done, Backup directory was created and at least one file backed up 
- SQL Server Rollback can be executed only if current hotfix has a record in SYS_PRODUCT_HOTFIX_TAB table.

1) Make sure that Backup was created (Application server only) via Install.ps1 script.

2) Open Powershell.exe as administrator

3) Navigate to the same folder where installation was running from:
	> cd "c:\someFolder\HF-xxx(6.1.8.xxx)"

4) Execute the script the way you installed the hotfix but with an additional parameter -Rollback appended to the end of argument line:
	
	a) for systems with single application server and single database server,
	   as well as for combo systems with application and database on single machine,
	   run from Application server (MSODBCSQL and SQLCMD required):

	   > .\Install.ps1 -Rollback

	b) for systems with multiple application servers and database on separate machine,
           on first application server run to upgrade both Application server and Database sever
	   (MSODBCSQL and SQLCMD required):

           > .\Install.ps1 -Rollback

           on rest of the application servers use value "Application" for -Server parameter to update only application server
	   (MSODBCSQL and SQLCMD not required):
              
	   > .\Install.ps1 -Server Application -Rollback

_____________________________________________
HELP

For more information on powershell script, please run help command:
	> help .\Install.ps1 -full

For even more details, visit https://ewiki.athoc.com/display/ES/Install.ps1

