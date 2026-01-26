from langchain_ollama import ChatOllama
from langchain.agents import create_agent
from tools.available_tools import run_terminal_command

class Krypton:
    def __init__(self):
        self.base_model = "qwen2.5:1.5b"
        self.system_prompt = "you are an ai model that can control this computer system using the availabel tools "
        self.model_krypton = ChatOllama(
            model=self.base_model,
                validate_model_on_init=True,
                temperature=0.1,
                num_predict=1000,
                reasoning=False       
        )



    def get_weather(self,city: str) -> str:
        """Get weather for a given city."""
        return f"It's always sunny in {city}!"



    def ai_krypton(self,message:str):
        messages = [
            ("system",self.system_prompt),
            ("human",message)
        ]    

        response = self.model_krypton.invoke(messages)
        return response.content
    




    def agent_krypton(self,message:str):
        agent = create_agent(
            model=self.model_krypton,
            tools=[self.get_weather,run_terminal_command],
            system_prompt=""
        )

        response = agent.invoke(
       {"messages": [{"role": "user", "content": message}]}
        )

        return response['messages'][1].content
    

    

if __name__ == "__main__":    
    ai=Krypton()
    print(ai.ai_krypton(message="hello !"))