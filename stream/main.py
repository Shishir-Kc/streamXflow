from langchain_groq import ChatGroq
from decouple import config
from langchain.agents import create_agent

import os

# loadenv()

model = ChatGroq(api_key=config('GROQ_API_KEY'),
                 model="openai/gpt-oss-120b"                 
                 )

# agent = create_agent(model=model)

# messages = { 
#     "messages":[
# {
#     'role':'user',
#     "content":"hello ! "
# }
#     ]


# }

while True:
    messages = [ 
    ("system",""),
    ("human",f"{input(">")}")
    ]

    response = model.invoke(messages)
    for chunk in model.stream(messages):
     print(chunk.text,end="")

    print()