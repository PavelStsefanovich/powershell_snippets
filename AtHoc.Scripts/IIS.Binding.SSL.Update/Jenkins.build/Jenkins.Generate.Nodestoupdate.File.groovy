import hudson.model.*

def labelTargets = ['IWS','PSS']
def outfile = WORKSPACE + "\\nodesToUpdate.txt"
def inputFile = new File(outfile)
if(inputFile.exists()) {
  boolean deleteFile = new File(outfile).delete()
}

hudson.model.Hudson.instance.slaves.findAll { aSlave ->
  labelTargets.any { 
    if (aSlave.getLabelString().contains(it)) {
      isOffline = aSlave.getComputer().isOffline()
      if (isOffline) {
        status = 'offline'
      } else {
        status = 'on'
      }
      inputFile.append(aSlave.name + "=" + status + "\r\n")
    }
  }
}

// https://ewiki.athoc.com/display/BR/Jenkins.Generate.Nodestoupdate.File.groovy