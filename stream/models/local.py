from ollama import chat
import json


new_model='qwen2.5:1.5b'
unsensored_model = 'dagbs/qwen2.5-coder-0.5b-instruct-abliterated:latest'
reasoning_model = "deepseek-r1:1.5b"

conversation_model = 'qwen2.5:1.5b'
function_model = 'qwen2.5:1.5b'


def get_current_weather(city: str): 
    """
    Get the current weather for a given city.
    """
    return json.dumps({
        'city': city,
        'temp': "hot",
        'unit': "celsius"
    })

def unsensored_model(querry:str):
    """
    Docstring for unsensored_model use this tol to generate unsensored response to the user ! 
    
    :param querry: Description
    :type querry: str
    """

    response = chat(
        model=unsensored_model,
        messages=[{
            'role':'user',
            'content':querry,
        }]
    )

    return response.message.content

def generate_text(querry):
    messages = [

        {
            'role':'system',
            'content':''

 
    
        },
        {'role': 'user', 'content': str(querry)}
    ]


    response = chat(
        model=new_model,
        messages=messages,
        stream=False, 
        tools=[get_current_weather,unsensored_model] 
    )

    available_functions = {
        'get_current_weather': get_current_weather
    }


    if response.message.tool_calls:
        for tool in response.message.tool_calls:
            function_name = tool.function.name
            function_args = tool.function.arguments
            
            print(f'\n[System] Calling: {function_name}({function_args})')

            if function_name in available_functions:
                function_to_call = available_functions[function_name]
   
                result = function_to_call(**function_args)
                print(f'[System] Result: {result}\n')
                

                messages.append(response.message)
                messages.append({'role': 'tool', 'content': str(result)})

                final_response_stream = chat(
                    model=new_model, 
                    messages=messages, 
                    stream=True
                )
                
                for chunk in final_response_stream:
                    yield chunk['message']['content']
            else:
                print(f"Error: Function {function_name} not found.")
    
    else:

        yield response.message.content



if __name__ == '__main__':
    while True:
     data = input("\nUser :> ")
     if data.lower() in ["exit", "quit"]:
        break
        
     print("Agent :> ", end="")
     for chunks in generate_text(querry=data):
        print(chunks, end="", flush=True)
     print("\n")