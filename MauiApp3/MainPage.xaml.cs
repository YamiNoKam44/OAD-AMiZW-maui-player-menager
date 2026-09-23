using MauiApp3.ViewModel;
using System;
using System.Collections.Generic;
using System.Text;

namespace MauiApp3
{
    public partial class MainPage : ContentPage
    {
        public MainPage(MainViewModel viewModel)
        {
            InitializeComponent();

            BindingContext = viewModel;
        }
    }
}
