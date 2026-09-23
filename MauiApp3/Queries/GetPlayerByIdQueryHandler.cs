using MauiApp3.Data;
using MauiApp3.Model;
using System;
using System.Collections.Generic;
using System.Text;

namespace MauiApp3.Queries
{
    public class GetPlayerByIdQueryHandler
    {
        private readonly PlayerRepository _playerRepository;
        public GetPlayerByIdQueryHandler(PlayerRepository playerRepository)
        {
            _playerRepository = playerRepository;
        }
        public Player? Handle(GetPlayerByIdQuery query)
        {
            return _playerRepository.Players.FirstOrDefault(player => player.Id == query.Id);
        }
    }
}
