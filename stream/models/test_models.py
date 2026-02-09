days = ['sunday','monday','tuesday','wednesday','thursday','friday','saturday']
user_number = int(input("enter a number 1-7 -> ")) -1  
if user_number>7 or user_number <0:
    print("Invalid days ! ")    
for i in days:
    if user_number == days.index(i):
        print(f" Day -> {days[user_number]}")
        break
