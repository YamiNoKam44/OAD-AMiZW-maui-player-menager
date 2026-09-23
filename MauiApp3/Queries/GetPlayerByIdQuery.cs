using System;
using System.Collections.Generic;
using System.Text;

namespace MauiApp3.Queries
{
    public class GetPlayerByIdQuery
    {
        public int Id { get; }
        public GetPlayerByIdQuery(int id)
        {
            Id = id;
        }
    }
}
