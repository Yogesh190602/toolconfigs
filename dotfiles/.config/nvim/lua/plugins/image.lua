return {
  {
    "folke/snacks.nvim",
    opts = {
      image = {
        enabled = true,
        -- Supported image formats
        formats = {
          "png",
          "jpg",
          "jpeg",
          "gif",
          "bmp",
          "webp",
          "tiff",
          "heic",
          "avif",
        },
      },
    },
    keys = {
      {
        "<leader>ui",
        function()
          Snacks.image.toggle()
        end,
        desc = "Toggle Image Display",
      },
    },
  },
}
