# bsti.Powershell
Powershell Modules

I'm going to be publishing a number of Powershell modules I've created over my career that have been a great help managing 
the IT resources I've been in charge of over the years.  

Please check back over time to see new code and additions to the project.  

Also, check out my blog at http://Get-CreativeTitle.com for full blog posts about the various pieces I've published.

INSTALLATION

As with all Powershell modules, these are easily installed.  Simply create a folder named the same as the module in your module directory and drop the .psm1, .psd1 files, and any other files in the module folder inside.  

The module folder can be located in a few places, but the most commonly-used one is:
c:\windows\system32\windowspowershell\v1.0\modules  #  Modules in here can be used by all users

(See https://technet.microsoft.com/en-us/library/hh847804.aspx for details on module locations)

Example:

Download bsti.conversion.psd1 and .psm1.

Place them in the following folder:

C:\windows\system32\windowspowershell\v1.0\modules\bsti.conversion
  bsti.conversion.psm1
  bsti.conversion.psd1

That's it!  Now you can launch a Powershell console and type Import-Module bsti.conversion


