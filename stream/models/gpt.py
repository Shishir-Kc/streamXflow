from langchain_groq import ChatGroq
from decouple import config
from langchain.agents import create_agent

import os

class Gpt:
   def __init__(self):
      self.api_key = config('GROQ_API_KEY')
      self.model = ChatGroq(api_key=self.api_key,
                 model="openai/gpt-oss-120b"                 
                 )
      
   def ai_gpt(self,message,outputlength:str=None):
      if outputlength:

        repsone= self.model.invoke(
         [
            ("human",f" {outputlength} {message}")
         ]
        )

        return repsone.text
      
      repsone= self.model.invoke(
         [
            ("human",message)
         ]
      )

      return repsone.text
      

if __name__ == "__main__":
   ai = Gpt()
   print(ai.ai_gpt(message="hello !"))