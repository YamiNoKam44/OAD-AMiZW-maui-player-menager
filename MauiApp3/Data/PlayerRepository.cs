using MauiApp3.Model;


namespace MauiApp3.Data
{
    public class PlayerRepository
    {
        public List<Player> Players { get; } = new()
        {
            new Player
            {
                Id = 1,
                Name = "test",
                Level = 1500,
            },
            new Player
            {
                Id = 31,
                Name = "noname",
                Level = 4021
            }
        };
    }
}
