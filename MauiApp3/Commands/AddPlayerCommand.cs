using System;
using System.Collections.Generic;
using System.Text;

namespace MauiApp3.Commands
{
    public class AddPlayerCommand
    {
        public string Name { get;}
        public int Level { get;}
        public AddPlayerCommand(string name, int level)
        {
            Name = name;
            Level = level;
        }
    }
}
