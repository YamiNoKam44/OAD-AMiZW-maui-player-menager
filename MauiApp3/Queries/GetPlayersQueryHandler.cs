using MauiApp3.Data;
using MauiApp3.Model;
using System;
using System.Collections.Generic;
using System.Text;

namespace MauiApp3.Queries
{
    public class GetPlayersQueryHandler
    {
        private readonly PlayerRepository _playerRepository;
        public GetPlayersQueryHandler(PlayerRepository playerRepository)
        {
            _playerRepository = playerRepository;
        }

        public List<Player> Handle(GetPlayersQuery query)
        {
            return _playerRepository.Players;
        } 
    }
}
