
using MauiApp3.Commands;
using MauiApp3.Model;
using MauiApp3.Queries;
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Text;
using System.Windows.Input;

namespace MauiApp3.ViewModel
{
    public class MainViewModel : INotifyPropertyChanged
    {
        private readonly GetPlayerByIdQueryHandler _getPlayerByIdQueryHandler;
        private readonly GetPlayersQueryHandler _getPlayersQueryHandler;
        private readonly AddPlayerCommandHandler _addPlayerCommandHandler;

        public event PropertyChangedEventHandler? PropertyChanged;

        public ObservableCollection<Player> Players { get; } = new();
        public string PlayerName { get; set; } = "";
        public string PlayerLevel { get; set; } = "";
        public string PlayerId { get; set; } = "";
        private string _searchResult = "";

        public string SearchResult
        {
            get
            {
                return _searchResult;
            }

            set
            {
                _searchResult = value;
                OnPropertyChanged();
            }
        }
        public ICommand AddPlayerCommandButton { get; }
        public ICommand FindPlayerCommandButton { get; }
        public MainViewModel(
            GetPlayerByIdQueryHandler getPlayerByIdQueryHandler,
            GetPlayersQueryHandler getPlayersQueryHandler,
            AddPlayerCommandHandler addPlayerCommandHandler)
        {
            _getPlayerByIdQueryHandler = getPlayerByIdQueryHandler;
            _getPlayersQueryHandler = getPlayersQueryHandler;
            _addPlayerCommandHandler = addPlayerCommandHandler;

            AddPlayerCommandButton = new Command(AddPlayer);
            FindPlayerCommandButton = new Command(FindPlayer);


            LoadPlayers();
        }
        private void AddPlayer()
        {
            if (!int.TryParse(PlayerLevel, out int playerLevel))
            {
                return;
            }
            AddPlayerCommand command = new AddPlayerCommand(PlayerName, playerLevel);
            _addPlayerCommandHandler.Handle(command);

            LoadPlayers();
        }
        private void FindPlayer()
        {
            if (!int.TryParse(PlayerId, out int playerId))
            {
                SearchResult = "Niepoprawne ID";
                return;
            }

            GetPlayerByIdQuery query =
                new GetPlayerByIdQuery(playerId);

            Player? player =
                _getPlayerByIdQueryHandler.Handle(query);

            if (player == null)
            {
                SearchResult = "Nie znaleziono gracza";
                return;
            }

            SearchResult =
                $"{player.Name} - poziom {player.Level}";
        }

        private void LoadPlayers()
        {
            GetPlayersQuery query = new GetPlayersQuery();
            List<Player> players = _getPlayersQueryHandler.Handle(query);

            Players.Clear();

            foreach (Player player in players)
            {
                Players.Add(player);
            }
        }

        protected void OnPropertyChanged(
            [CallerMemberName] string?  propertyName = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}
