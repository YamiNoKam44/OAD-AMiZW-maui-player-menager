using MauiApp3.Data;
using MauiApp3.Model;
using System;
using System.Collections.Generic;
using System.Text;

namespace MauiApp3.Commands
{
    public class AddPlayerCommandHandler
    {
        private readonly PlayerRepository _playerRepository;
        public AddPlayerCommandHandler(PlayerRepository playerRepository)
        {
            _playerRepository = playerRepository;
        }
        public void Handle(AddPlayerCommand command)
        {
            Player player = new Player
            {
                Id = _playerRepository.Players.Count + 1,
                Name = command.Name,
                Level = command.Level,
            };

            _playerRepository.Players.Add(player);
        }
    }
}