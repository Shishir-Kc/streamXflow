import subprocess
import os


def run_terminal_command(command:str) ->str:
    """
        use this tool to run terminal commands 
    
        
    ARGS:
        command: add terminal commands of linux to interact with system !
    
 
    """
    os.chdir("/home/x64")
    print("command runned by krypton - > ",command)
    result = subprocess.run(command,capture_output=True,text=True)

    print(result.stdout)

    return{
        'output' : result.stdout
    }





