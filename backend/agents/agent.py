# pip install -qU langchain "langchain[anthropic]"
from langchain.agents import create_agent
from langchain_groq import ChatGroq


llm = ChatGroq(
    model='openai/gpt-oss-120b',
)
def get_weather(city: str) -> str:
    """Get weather for a given city."""
    return f"It's always sunny in {city}!"

agent = create_agent(
    model=llm,
    # model_provider = 'groq',
    tools=[get_weather]
)


print(agent.invoke(
    {"messages": [{"role": "user", "content": "what is the weather in sf"}]}
))


# agent = create_agent(
#     model=llm,
#     tools=[get_weather],
#     system_prompt="You are a helpful assistant",
# )

# while True:

#     messages = [
#     ("system", "You are a helpful ai ."),
#     ("human", f"{input(":>")}"),
# ]
#     print("\n")

#     llm.invoke(messages)
#  # Streaming `text` for each content chunk received
#     for chunk in llm.stream(messages):
#          print(chunk.text, end="")
    

# print("\n")